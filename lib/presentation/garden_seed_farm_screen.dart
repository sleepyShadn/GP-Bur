// ========== lib/presentation/garden_seed_farm_screen.dart ==========
import 'dart:async';

import 'package:flutter/material.dart';

import '../data/garden_data.dart';
import '../domain/garden_logic.dart';
import 'garden_planted_item.dart';

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

  String _userId = '';
  int _points = 0;
  String _currentSeason = 'Spring';

  Map<String, int> _seedsInventory = {
    'Regular Seeds': 2,
    'Rare Seeds': 2,
    'Legendary Seeds': 2,
    'Growth Accelerator': 1,
  };

  List<PlantedItem> _plantedItems = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.initialSeason;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        for (final PlantedItem item in _plantedItems) {
          if (!item.isFullyGrown && item.plantTime != null) {
            item.updateRemainingTime();
          }
        }
      });
    });
    _bootstrap();
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
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      setState(() => _plantedItems = items);
    }
  }

  void _snack(String message, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bg, duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _useSeed(String seedType) async {
    if (_userId.isEmpty) {
      _snack('Please log in first', Colors.red);
      return;
    }
    if (_seedsInventory[seedType]! <= 0) {
      _snack('You don\'t have this item in your inventory', Colors.orange);
      return;
    }
    if (seedType == 'Growth Accelerator') {
      await _useGrowthAccelerator();
    } else {
      await _plantSeed(seedType);
    }
  }

  Future<void> _plantSeed(String seedType) async {
    try {
      final posX = 30 + (_plantedItems.length % 5) * 50.0;
      final posY = 30 + ((_plantedItems.length ~/ 5) % 3) * 50.0;
      final durationSeconds = _logic.getSeedDuration(seedType);
      final plantTime = DateTime.now();

      final docId = await _data.plantSeed(
        _userId,
        seedType,
        plantTime,
        durationSeconds,
        posX,
        posY,
      );

      if (docId != null && mounted) {
        setState(() {
          _seedsInventory[seedType] = _seedsInventory[seedType]! - 1;
          _plantedItems.add(PlantedItem(
            id: docId,
            seedType: seedType,
            color: _logic.getSeedColor(seedType),
            icon: Icons.spa,
            position: Offset(posX, posY),
            isAccelerated: false,
            plantTime: plantTime,
            durationSeconds: durationSeconds,
            remainingSeconds: durationSeconds,
            isFullyGrown: false,
            docId: docId,
          ));
        });
        await _data.updateSeedsInventory(_userId, seedType, _seedsInventory[seedType]!);
      }
    } catch (e) {
      debugPrint('Error planting seed: $e');
      _snack('Error planting seed', Colors.red);
    }
  }

  Future<void> _useGrowthAccelerator() async {
    if (_plantedItems.isEmpty) {
      _snack('No plants to accelerate', Colors.orange);
      return;
    }
    try {
      setState(() {
        _seedsInventory['Growth Accelerator'] = _seedsInventory['Growth Accelerator']! - 1;
      });
      for (final PlantedItem item in _plantedItems) {
        if (!item.isFullyGrown) {
          await _data.acceleratePlant(_userId, item.docId);
          item.applyAccelerator();
        }
      }
      await _data.updateSeedsInventory(
        _userId,
        'Growth Accelerator',
        _seedsInventory['Growth Accelerator']!,
      );
      _snack('Growth Accelerator applied successfully!', const Color(0xff7f9461));
    } catch (e) {
      debugPrint('Error using accelerator: $e');
      _snack('Error using accelerator', Colors.red);
    }
  }

  Future<void> _harvestPlant(PlantedItem item) async {
    if (!item.isFullyGrown) return;
    try {
      final harvestPoints = _logic.getHarvestPoints(item.seedType);
      await _data.harvestPlant(_userId, item.docId, harvestPoints);
      if (mounted) {
        setState(() {
          _points += harvestPoints;
          _plantedItems.remove(item);
        });
        _snack('Harvested! +$harvestPoints points', const Color(0xff7f9461));
      }
    } catch (e) {
      debugPrint('Error harvesting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color seasonAccent = _logic.getSeasonIconColor(_currentSeason);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _logic.seasonalFarmGradient(_currentSeason),
          ),
        ),
        child: SafeArea(
          child: _userId.isEmpty
              ? _buildNoUser()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar(seasonAccent)),
                    SliverToBoxAdapter(child: _buildSeasonStrip(seasonAccent)),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    SliverToBoxAdapter(child: _buildPlotBoard(seasonAccent)),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                    SliverToBoxAdapter(child: _buildInventoryCard(seasonAccent)),
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildNoUser() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle, size: 72, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(height: 12),
            const Text(
              'Sign in to use your plots',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3D2914)),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.agriculture_rounded, color: accent, size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Seed & harvest',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3D2914),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD4A574)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFC9A227), size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '$_points',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF5C4018),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonStrip(Color accent) {
    const seasons = ['Spring', 'Summer', 'Autumn', 'Winter'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _logic.seasonalRitualLine(_currentSeason),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3D2914).withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: seasons.map((season) {
                final bool sel = _currentSeason == season;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: sel ? _logic.getSeasonIconColor(season) : Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(18),
                    elevation: sel ? 3 : 0,
                    child: InkWell(
                      onTap: () => setState(() => _currentSeason = season),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        child: Row(
                          children: [
                            Icon(
                              _logic.getSeasonIconForPicker(season),
                              size: 18,
                              color: sel ? Colors.white : _logic.getSeasonIconColor(season),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              season,
                              style: TextStyle(
                                color: sel ? Colors.white : Colors.black87,
                                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlotBoard(Color accent) {
    return Container(
      width: double.infinity,
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF8B6914), width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 8)),
        ],
        color: _logic.getBoardColor(_currentSeason),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_logic.seasonalBackgroundAsset(_currentSeason) != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.38,
                  child: Image.asset(
                    _logic.seasonalBackgroundAsset(_currentSeason)!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(painter: _PlotGridPainter(accent.withValues(alpha: 0.12))),
            ),
            Opacity(
              opacity: 0.22,
              child: Icon(_logic.getSeasonIcon(_currentSeason), size: 140, color: accent),
            ),
            ..._plantedItems.map((item) {
              return Positioned(
                left: item.position.dx,
                top: item.position.dy,
                child: GestureDetector(
                  onTap: () {
                    if (item.isFullyGrown) _harvestPlant(item);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: item.isFullyGrown ? item.color.withValues(alpha: 0.95) : item.color.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.isFullyGrown ? const Color(0xFFFFE566) : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [BoxShadow(color: item.color.withValues(alpha: 0.45), blurRadius: 8)],
                        ),
                        child: Icon(item.isFullyGrown ? Icons.spa : item.icon, color: Colors.white, size: 24),
                      ),
                      if (!item.isFullyGrown)
                        Positioned(
                          bottom: -16,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _logic.formatTime(item.remainingSeconds),
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      if (item.isAccelerated)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Icon(Icons.bolt, color: Colors.white, size: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (_plantedItems.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_logic.getSeasonIcon(_currentSeason), size: 56, color: accent),
                    const SizedBox(height: 8),
                    Text(
                      'Tap seeds below to plant your first crop',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: accent.withValues(alpha: 0.95), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(Color accent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8DCC8), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Seed shed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF3D2914)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _seedsInventory.entries.map((e) => _seedChip(e.key, e.value)).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Mature plants glow — tap to harvest. Growth Accelerator ripens every plot at once.',
            style: TextStyle(fontSize: 11.5, color: Colors.brown.shade600, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _seedChip(String seedType, int quantity) {
    final seedInfo = _logic.getSeedInfo(seedType);
    final bool hasItem = quantity > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _useSeed(seedType),
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: hasItem ? 1 : 0.45,
          child: Container(
            width: 88,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (seedInfo['color'] as Color).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: (seedInfo['color'] as Color).withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(seedInfo['icon'] as IconData, color: seedInfo['color'] as Color, size: 26),
                const SizedBox(height: 6),
                Text(
                  seedInfo['displayName'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: seedInfo['color'] as Color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: hasItem ? seedInfo['color'] as Color : Colors.grey,
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

class _PlotGridPainter extends CustomPainter {
  _PlotGridPainter(this.line);

  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = line
      ..strokeWidth = 1;
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
