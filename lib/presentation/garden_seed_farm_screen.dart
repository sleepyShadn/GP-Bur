// ========== lib/presentation/garden_seed_farm_screen.dart ==========
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../data/garden_care_data.dart';
import '../services/garden_care_notification_coordinator.dart';
import '../services/notification_service.dart';
import '../data/garden_data.dart';
import '../domain/garden_care_logic.dart';
import '../domain/garden_logic.dart';
import '../services/garden_audio_service.dart';
import 'garden_flame_world.dart';
import 'garden_planted_item.dart';

enum _GardenToolMode { plant, harvest, remove }

/// Plant seeds, grow crops, and harvest — opened from the main Garden hub.
class GardenSeedFarmScreen extends StatefulWidget {
  const GardenSeedFarmScreen({super.key, required this.initialSeason});

  final String initialSeason;

  @override
  State<GardenSeedFarmScreen> createState() => _GardenSeedFarmScreenState();
}

class _GardenSeedFarmScreenState extends State<GardenSeedFarmScreen> {
  final GardenLogic _logic = GardenLogic();
  final GardenData _data = GardenData();
  final GardenCareData _gardenCareData = GardenCareData();
  final GardenAudioService _audio = GardenAudioService();
  late final GardenFlameWorld _flameWorld;

  String _userId = '';
  int _points = 0;
  int _gardenVitality = GardenCareLogic.defaultVitality;
  String _currentSeason = 'Spring';
  String? _selectedSeedType;
  _GardenToolMode _toolMode = _GardenToolMode.plant;
  bool _toolsExpanded = false;

  Map<String, int> _seedsInventory = {
    'Regular Seeds': 2,
    'Rare Seeds': 2,
    'Legendary Seeds': 2,
    GardenLogic.fertilizerInventoryKey: 1,
  };

  /// World canvas (pan only). Layout inspired by classic isometric farm games.
  static const double _worldW = 1180;
  static const double _worldH = 1020;

  /// Central crop bed — 7×5 like many casual farm UIs.
  static const int _cropCols = 7;
  static const int _cropRows = 5;
  static const double _plotCell = 74;
  static const double _cropPad = 14;
  static const double _cropOriginX = 320;
  static const double _cropOriginY = 360;

  List<PlantedItem> _plantedItems = [];
  Timer? _timer;
  bool _didPrecacheImages = false;
  bool _audioReady = false;

  static const Map<String, String> _seasonAssetByName = <String, String>{
    'Spring': 'assets/spring.jpeg',
    'Summer': 'assets/sunny.jpeg',
    'Autumn': 'assets/automun.jpeg',
    'Winter': 'assets/winter.jpeg',
  };

  /// Falling-leaves style overlay for Autumn only (see `assets/animations/plant.json`).
  static const String _autumnLeavesLottie = 'assets/animations/plant.json';

  static const Map<String, String> _flowerAssetByStage = <String, String>{
    'early': 'assets/flower0.jpeg',
    'mid': 'assets/flower1.jpeg',
    'complete_regular': 'assets/flower_complete_red.jpeg',
    'complete_rare': 'assets/flower_complete_blue.jpeg',
    'complete_legendary': 'assets/flower_complete_purple.jpeg',
  };

  @override
  void initState() {
    super.initState();
    _setLandscape();
    _initAudio();
    _flameWorld = GardenFlameWorld(
      onPlotTap: (int idx) => _onTileTap(idx),
      cropCols: _cropCols,
      cropRows: _cropRows,
      plotCell: _plotCell,
      cropPad: _cropPad,
      cropOriginX: _cropOriginX,
      cropOriginY: _cropOriginY,
      worldWidth: _worldW,
      worldHeight: _worldH,
    );
    _currentSeason = widget.initialSeason;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      bool anyGrowing = false;
      for (final PlantedItem item in _plantedItems) {
        if (!item.isFullyGrown && item.plantTime != null) {
          anyGrowing = true;
          item.updateRemainingTime();
        }
      }
      // Rebuild every tick while something grows so countdown chips stay accurate
      // (visual stage can sit in "seed" for a long time; chip must still tick).
      if (anyGrowing) {
        setState(() {});
      }
    });
    _bootstrap();
  }

  Future<void> _initAudio() async {
    await _audio.init();
    await _audio.startGardenCareBgm();
    _audioReady = true;
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheImages) {
      _didPrecacheImages = true;
      for (final String path in _seasonAssetByName.values) {
        precacheImage(AssetImage(path), context);
      }
      for (final String path in _flowerAssetByStage.values) {
        precacheImage(AssetImage(path), context);
      }
    }
  }

  Future<void> _bootstrap() async {
    final user = await _data.getCurrentUser();
    if (!mounted) return;
    if (user == null) {
      setState(() => _userId = '');
      return;
    }
    setState(() => _userId = user['uid'] ?? '');
    await _loadUserData();
    await _loadGardenData();
    await _refreshGardenCareState();
  }

  Future<void> _refreshGardenCareState() async {
    if (_userId.isEmpty) return;
    final int v = await _gardenCareData.loadAndReconcileVitality(_userId);
    if (mounted) {
      setState(() => _gardenVitality = v);
    }
  }

  @override
  void dispose() {
    _flameWorld.cameraListenable.dispose();
    _timer?.cancel();
    _audio.dispose();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final data = await _data.loadUserData(_userId);
    if (data != null && mounted) {
      setState(() {
        _points = data['points'] ?? 0;
        _seedsInventory = data['seedsInventory'] ?? _seedsInventory;
      });
    }
  }

  Future<void> _loadGardenData() async {
    final items = await _data.loadGardenData(_userId, _logic.getSeedColor);
    if (items != null && mounted) {
      final Set<int> used = <int>{};
      final List<PlantedItem> snapped = <PlantedItem>[];
      for (final PlantedItem it in items) {
        int? idx = _cropIndexFromWorld(it.position);
        if (idx == null || used.contains(idx)) {
          idx = null;
          for (int j = 0; j < _cropTileCount; j++) {
            if (!used.contains(j)) {
              idx = j;
              break;
            }
          }
          idx ??= 0;
        }
        used.add(idx);
        snapped.add(it.copyWith(position: _cropCellWorldCenter(idx)));
      }
      setState(() => _plantedItems = snapped);
    }
  }

  void _snack(
    String message,
    Color bg, {
    IconData icon = Icons.notifications_active_rounded,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.42), width: 1.2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.7,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _plantSeedAt(String seedType, Offset position) async {
    try {
      final durationSeconds = _logic.getSeedDuration(seedType);
      final plantTime = DateTime.now();

      final docId = await _data.plantSeed(
        _userId,
        seedType,
        plantTime,
        durationSeconds,
        position.dx,
        position.dy,
      );

      if (docId != null && mounted) {
        setState(() {
          _seedsInventory[seedType] = _seedsInventory[seedType]! - 1;
          _plantedItems.add(PlantedItem(
            id: docId,
            seedType: seedType,
            color: _logic.getSeedColor(seedType),
            icon: Icons.spa,
            position: position,
            isAccelerated: false,
            plantTime: plantTime,
            durationSeconds: durationSeconds,
            remainingSeconds: durationSeconds,
            isFullyGrown: false,
            docId: docId,
          ));
          if (_seedsInventory[seedType] == 0 && _selectedSeedType == seedType) {
            _selectedSeedType = null;
          }
        });
        await _data.updateSeedsInventory(
            _userId, seedType, _seedsInventory[seedType]!);
        await _gardenCareData.recordPlantCareBoost(_userId);
        await GardenCareNotificationCoordinator().syncForUser(_userId);
        await _refreshGardenCareState();
        unawaited(
          NotificationService().showGardenPlantEncouragement(
            seedType: seedType,
            userId: _userId,
          ),
        );
        if (_audioReady) {
          await _audio.playToolGrab();
        }
      }
    } catch (e) {
      debugPrint('Error planting seed: $e');
      _snack('Error planting seed', Colors.red);
    }
  }

  Future<void> _useFertilizer() async {
    if (_plantedItems.isEmpty) {
      _snack('No plants to accelerate', Colors.orange);
      return;
    }
    final List<PlantedItem> growing = _plantedItems
        .where((PlantedItem e) => !e.isFullyGrown)
        .toList();
    if (growing.isEmpty) {
      _snack(
        'Nothing to boost — all plots are already ready to harvest.',
        Colors.orange,
        icon: Icons.info_outline_rounded,
      );
      return;
    }
    if ((_seedsInventory[GardenLogic.fertilizerInventoryKey] ?? 0) <= 0) {
      _snack('No Fertilizer in inventory.', Colors.orange);
      return;
    }
    try {
      final Map<String, DateTime> applied = <String, DateTime>{};
      for (final PlantedItem item in growing) {
        final DateTime? newPlantTime =
            await _data.acceleratePlantGrowDay(_userId, item.docId);
        if (newPlantTime != null) {
          applied[item.docId] = newPlantTime;
        }
      }
      if (applied.isEmpty) {
        if (mounted) {
          _snack(
            'Could not apply boost — try again.',
            Colors.red,
            icon: Icons.error_outline_rounded,
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _seedsInventory[GardenLogic.fertilizerInventoryKey] =
            _seedsInventory[GardenLogic.fertilizerInventoryKey]! - 1;
        for (final PlantedItem item in growing) {
          final DateTime? t = applied[item.docId];
          if (t != null) {
            item.syncAfterGrowthAdvance(t);
          }
        }
      });
      await _data.updateSeedsInventory(
        _userId,
        GardenLogic.fertilizerInventoryKey,
        _seedsInventory[GardenLogic.fertilizerInventoryKey]!,
      );
      _snack(
        'Fertilizer applied: each growing plant skipped ~1 day of grow time. Keep up daily care for vitality!',
        const Color(0xff7f9461),
        icon: Icons.bolt_rounded,
      );
      if (_audioReady) {
        await _audio.playFertilizerPour();
      }
      await _refreshGardenCareState();
    } catch (e) {
      debugPrint('Error using fertilizer: $e');
      _snack('Error using fertilizer', Colors.red);
    }
  }

  Future<void> _harvestPlant(PlantedItem item) async {
    if (!item.isFullyGrown) return;
    try {
      final harvestPoints = _logic.getHarvestPoints(item.seedType);
      await _data.harvestPlant(_userId, item.docId, harvestPoints);
      if (mounted) {
        _flameWorld.triggerHarvestFx(at: item.position, points: harvestPoints);
        setState(() {
          _points += harvestPoints;
          _plantedItems.remove(item);
        });
        _snack(
          'Harvested! +$harvestPoints points',
          const Color(0xff7f9461),
          icon: Icons.auto_awesome_rounded,
        );
        if (_audioReady) {
          await _audio.playLevelUp();
        }
        await _refreshGardenCareState();
      }
    } catch (e) {
      debugPrint('Error harvesting: $e');
    }
  }

  Future<void> _removePlant(PlantedItem item) async {
    try {
      await _data.harvestPlant(_userId, item.docId, 0);
      if (mounted) {
        setState(() => _plantedItems.remove(item));
        _snack('Plant removed from plot.', Colors.blueGrey,
            icon: Icons.delete_outline_rounded);
        if (_audioReady) {
          await _audio.playWeedWaste();
        }
        await _refreshGardenCareState();
      }
    } catch (e) {
      debugPrint('Error removing plant: $e');
      _snack('Error removing plant', Colors.red);
    }
  }

  int get _cropTileCount => _cropCols * _cropRows;

  Offset _cropCellWorldCenter(int index) {
    final int row = index ~/ _cropCols;
    final int col = index % _cropCols;
    return Offset(
      _cropOriginX + _cropPad + col * _plotCell + _plotCell * 0.5,
      _cropOriginY + _cropPad + row * _plotCell + _plotCell * 0.5,
    );
  }

  int? _cropIndexFromWorld(Offset pos) {
    final double ix = pos.dx - _cropOriginX - _cropPad;
    final double iy = pos.dy - _cropOriginY - _cropPad;
    if (ix < 0 || iy < 0) return null;
    final int col = (ix / _plotCell).floor();
    final int row = (iy / _plotCell).floor();
    if (col < 0 || row < 0 || col >= _cropCols || row >= _cropRows) return null;
    return row * _cropCols + col;
  }

  int _cropIndexForPlant(PlantedItem item) {
    final int? hit = _cropIndexFromWorld(item.position);
    if (hit != null) return hit;
    double best = double.infinity;
    int bestIdx = 0;
    for (int i = 0; i < _cropTileCount; i++) {
      final double d = (item.position - _cropCellWorldCenter(i)).distance;
      if (d < best) {
        best = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  PlantedItem? _itemAtIndex(int index) {
    for (final PlantedItem item in _plantedItems) {
      if (_cropIndexForPlant(item) == index) return item;
    }
    return null;
  }

  Future<void> _onTileTap(int index) async {
    if (index < 0 || index >= _cropTileCount) return;

    final PlantedItem? existing = _itemAtIndex(index);
    if (existing != null) {
      if (_toolMode == _GardenToolMode.remove) {
        await _removePlant(existing);
        return;
      }
      if (_toolMode == _GardenToolMode.harvest) {
        if (existing.isFullyGrown) {
          await _harvestPlant(existing);
        } else {
          _snack('This crop is still growing.', Colors.blueGrey);
        }
        return;
      }
      if (existing.isFullyGrown) {
        _snack('Switch to Harvest tool to collect this crop.', Colors.orange);
      } else {
        _snack('This plot is already planted.', Colors.blueGrey);
      }
      return;
    }

    if (_toolMode != _GardenToolMode.plant) {
      _snack('Switch to Plant tool to sow seeds.', Colors.orange);
      return;
    }

    final String? selected = _selectedSeedType;
    if (selected == null) {
      _snack('Choose a seed first from the seed shed.', Colors.orange);
      return;
    }
    if ((_seedsInventory[selected] ?? 0) <= 0) {
      _snack('This seed is out of stock.', Colors.orange);
      return;
    }
    await _plantSeedAt(selected, _cropCellWorldCenter(index));
  }

  _GrowthStage _growthStageFor(PlantedItem item) {
    if (item.isFullyGrown) return _GrowthStage.mature;
    final int denom = item.durationSeconds <= 0 ? 1 : item.durationSeconds;
    final double timeProgress =
        (1 - (item.remainingSeconds / denom)).clamp(0.0, 1.0);
    final double visualProgress = GardenCareLogic.growthVisualProgress(
      timeProgress01: timeProgress,
      vitality: _gardenVitality,
    );
    if (visualProgress < 0.28) return _GrowthStage.seed;
    return _GrowthStage.young;
  }

  @override
  Widget build(BuildContext context) {
    final Color seasonAccent = _logic.getSeasonIconColor(_currentSeason);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        _onExitPressed();
      },
      child: Scaffold(
        body: _userId.isEmpty
            ? _buildNoUser()
            : Stack(
                children: [
                  Positioned.fill(child: _buildWorldMap(seasonAccent)),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(seasonAccent),
                          const SizedBox(height: 8),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 620),
                              child: AnimatedCrossFade(
                                duration: const Duration(milliseconds: 220),
                                crossFadeState: _toolsExpanded
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                firstChild: _buildToolsCompactBar(seasonAccent),
                                secondChild: _buildInventoryCard(seasonAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onExitPressed() async {
    if (_audioReady) {
      await _audio.playButtonTap();
    }
    final bool confirmed = await _showExitDialog();
    if (!confirmed || !mounted) return;
    if (_audioReady) {
      await _audio.haltAllPlayback();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _showExitDialog() async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF1E3528), Color(0xFF2D4F3B)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28), width: 1.2),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Icon(Icons.exit_to_app_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Exit Farm Game?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your planted crops stay saved. Do you want to leave now?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.8,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text('Stay',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text('Exit',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Widget _buildNoUser() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _logic.seasonalFarmGradient(_currentSeason),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle,
                  size: 72, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(height: 12),
              const Text(
                'Sign in to use your plots',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x33131724),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.33), width: 1.4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Icon(_logic.getSeasonIconForPicker(_currentSeason),
              color: accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_currentSeason season',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _logic.seasonalRitualLine(_currentSeason),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: accent, size: 18),
                const SizedBox(width: 4),
                Text(
                  '$_points',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Exit game',
            child: InkWell(
              onTap: _onExitPressed,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.exit_to_app_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 5),
                    Text(
                      'Exit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorldMap(Color accent) {
    _flameWorld.setScene(season: _currentSeason, plants: _plantedItems);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _flameWorld
            .setViewport(Size(constraints.maxWidth, constraints.maxHeight));
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) {
                  _flameWorld.panBy(details.delta);
                },
                onTapUp: (TapUpDetails details) =>
                    _flameWorld.handleTap(details.localPosition),
                child: GameWidget<GardenFlameWorld>(game: _flameWorld),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _GardenBalancePainter()),
              ),
            ),
            ValueListenableBuilder<Offset>(
              valueListenable: _flameWorld.cameraListenable,
              builder: (BuildContext context, Offset cam, Widget? child) {
                return Transform.translate(
                  offset: Offset(-cam.dx, -cam.dy),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ..._buildTreeLottieOverlaysWorld(),
                      ..._buildPlantGrowthOverlaysWorld(),
                    ],
                  ),
                );
              },
            ),
            if (_currentSeason == 'Autumn') _buildAutumnFallingLeavesLayer(),
          ],
        );
      },
    );
  }

  /// Full-screen ambient animation (leaves); does not intercept touches.
  Widget _buildAutumnFallingLeavesLayer() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Opacity(
            opacity: 0.78,
            child: Lottie.asset(
              _autumnLeavesLottie,
              repeat: true,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTreeLottieOverlaysWorld() {
    final List<Offset> treeWorld = <Offset>[
      const Offset(96, 465),
      const Offset(1020, 488),
      const Offset(1070, 610),
      const Offset(160, 760),
    ];
    return treeWorld.map((Offset world) {
      return Positioned(
        left: world.dx - 60,
        top: world.dy - 120,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.72,
            child: SizedBox(
              width: 120,
              height: 140,
              child: Lottie.asset(
                'assets/animations/Tree in the wind.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildPlantGrowthOverlaysWorld() {
    return _plantedItems.map((PlantedItem item) {
      final _GrowthStage stage = _growthStageFor(item);
      final Offset world = item.position;
      if (stage == _GrowthStage.seed) {
        return Positioned(
          left: world.dx - 26,
          top: world.dy - 30,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!item.isFullyGrown) _buildPlantClockChip(item),
                const SizedBox(height: 2),
                Container(
                  width: 18,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D4037),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFF3E2723), width: 1),
                  ),
                ),
                const SizedBox(height: 1),
                Container(
                  width: 20,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final bool isMature = stage == _GrowthStage.mature;
      return Positioned(
        left: world.dx - 25,
        top: world.dy - (isMature ? 56 : 48),
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMature) _buildPlantClockChip(item),
              SizedBox(
                width: isMature ? 52 : 46,
                height: isMature ? 62 : 54,
                child: Lottie.asset(
                  isMature
                      ? _logic.matureBloomLottieAsset(item.seedType)
                      : 'assets/animations/Plant Gray.json',
                  repeat: true,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPlantClockChip(PlantedItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        _logic.formatGrowthRemaining(item.remainingSeconds),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: BoxDecoration(
        color: const Color(0x2E131724),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: <Widget>[
              const Icon(Icons.inventory_2_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tools & Seeds',
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.98),
                ),
              ),
              const Spacer(),
              _toolButton(
                icon: Icons.grass_rounded,
                label: 'Plant',
                count: 0,
                enabled: true,
                selected: _toolMode == _GardenToolMode.plant,
                color: const Color(0xFF2E7D32),
                onTap: () => setState(() => _toolMode = _GardenToolMode.plant),
              ),
              const SizedBox(width: 6),
              _toolButton(
                icon: Icons.content_cut_rounded,
                label: 'Harvest',
                count: 0,
                enabled: true,
                selected: _toolMode == _GardenToolMode.harvest,
                color: const Color(0xFFEF6C00),
                onTap: () =>
                    setState(() => _toolMode = _GardenToolMode.harvest),
              ),
              const SizedBox(width: 6),
              _toolButton(
                icon: Icons.delete_outline_rounded,
                label: 'Remove',
                count: 0,
                enabled: true,
                selected: _toolMode == _GardenToolMode.remove,
                color: const Color(0xFFC62828),
                onTap: () => setState(() => _toolMode = _GardenToolMode.remove),
              ),
              const SizedBox(width: 6),
              _toolButton(
                icon: Icons.eco_outlined,
                label: 'Fertilizer',
                count: _seedsInventory[GardenLogic.fertilizerInventoryKey] ?? 0,
                enabled:
                    (_seedsInventory[GardenLogic.fertilizerInventoryKey] ?? 0) >
                        0,
                selected: false,
                color: const Color(0xFFEF8B17),
                onTap: _useFertilizer,
              ),
              const SizedBox(width: 6),
              _miniToolIcon(
                icon: Icons.expand_less_rounded,
                selected: false,
                color: Colors.blueGrey,
                onTap: () => setState(() => _toolsExpanded = false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _seedsInventory.entries
                  .where((MapEntry<String, int> e) =>
                      e.key != GardenLogic.fertilizerInventoryKey)
                  .map((MapEntry<String, int> e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _seedChip(e.key, e.value),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedSeedType == null
                ? 'Tool: ${_toolMode.name.toUpperCase()} — choose a seed then tap a plot.'
                : 'Tool: ${_toolMode.name.toUpperCase()} — selected: $_selectedSeedType',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsCompactBar(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x2A131724),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.build_circle_outlined, color: accent, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Tool: ${_toolMode.name.toUpperCase()}  |  Seed: ${_selectedSeedType ?? 'None'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _miniToolIcon(
            icon: Icons.grass_rounded,
            selected: _toolMode == _GardenToolMode.plant,
            color: const Color(0xFF4CAF50),
            onTap: () => setState(() => _toolMode = _GardenToolMode.plant),
          ),
          const SizedBox(width: 4),
          _miniToolIcon(
            icon: Icons.content_cut_rounded,
            selected: _toolMode == _GardenToolMode.harvest,
            color: const Color(0xFFFF9800),
            onTap: () => setState(() => _toolMode = _GardenToolMode.harvest),
          ),
          const SizedBox(width: 4),
          _miniToolIcon(
            icon: Icons.delete_outline_rounded,
            selected: _toolMode == _GardenToolMode.remove,
            color: const Color(0xFFE53935),
            onTap: () => setState(() => _toolMode = _GardenToolMode.remove),
          ),
          const SizedBox(width: 4),
          _miniToolIcon(
            icon: Icons.expand_more_rounded,
            selected: false,
            color: Colors.blueGrey,
            onTap: () => setState(() => _toolsExpanded = true),
          ),
        ],
      ),
    );
  }

  Widget _miniToolIcon({
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_audioReady) {
            _audio.playButtonTap();
          }
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.95)
                : color.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.85 : 0.35)),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }

  Widget _seedChip(String seedType, int quantity) {
    final seedInfo = _logic.getSeedInfo(seedType);
    final bool hasItem = quantity > 0;
    final bool isSelected = _selectedSeedType == seedType;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_audioReady) {
            _audio.playButtonTap();
          }
          if (!hasItem) {
            _snack('No stock left for this seed.', Colors.orange);
            return;
          }
          setState(() {
            _selectedSeedType = isSelected ? null : seedType;
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: hasItem ? 1 : 0.45,
          child: Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isSelected ? 0.24 : 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? (seedInfo['color'] as Color).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(seedInfo['icon'] as IconData,
                    color: seedInfo['color'] as Color, size: 22),
                const SizedBox(height: 3),
                Text(
                  seedInfo['displayName'] as String,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.97),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasItem ? Colors.white : Colors.grey.shade300,
                  ),
                ),
                if (isSelected) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color:
                          (seedInfo['color'] as Color).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Selected',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: (seedInfo['color'] as Color),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required int count,
    required bool enabled,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !enabled
            ? null
            : () {
                if (_audioReady) {
                  _audio.playButtonTap();
                }
                onTap();
              },
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.95)
                  : color.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.5),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  count > 0 ? '$label  $count' : label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _GrowthStage { seed, young, mature }

class _GardenBalancePainter extends CustomPainter {
  const _GardenBalancePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stone = Paint()
      ..color = const Color(0xFFD7CCC8).withValues(alpha: 0.28);
    final Paint path = Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: 0.17)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final Path leftCurve = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.16, size.height * 0.64,
          size.width * 0.28, size.height * 0.76);
    final Path rightCurve = Path()
      ..moveTo(size.width, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.82, size.height * 0.62,
          size.width * 0.68, size.height * 0.75);
    canvas.drawPath(leftCurve, path);
    canvas.drawPath(rightCurve, path);

    for (int i = 0; i < 12; i++) {
      final double x = 30 + (i * (size.width - 60) / 11);
      final double y = size.height * 0.82 + ((i % 3) * 5);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 10, height: 5), stone);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
