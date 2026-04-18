// ========== lib/presentation/harvest_run_screen.dart ==========
import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:appforhumman/data/harvest_run_data.dart';
import 'package:appforhumman/domain/harvest_run_logic.dart';
import 'package:appforhumman/domain/harvest_run_models.dart';
import 'package:appforhumman/services/garden_audio_service.dart';
import 'package:lottie/lottie.dart';

enum _HarvestPhase { intro, playing }

Color _harvestCropAccent(HarvestCrop crop) {
  return switch (crop) {
    HarvestCrop.tomato => const Color(0xFFFB7185),
    HarvestCrop.carrot => const Color(0xFFFDBA74),
    HarvestCrop.lettuce => const Color(0xFF86EFAC),
    HarvestCrop.pepper => const Color(0xFFF87171),
    HarvestCrop.corn => const Color(0xFFFDE047),
  };
}

class HarvestRunScreen extends StatefulWidget {
  const HarvestRunScreen({super.key});

  @override
  State<HarvestRunScreen> createState() => _HarvestRunScreenState();
}

class _HarvestRunScreenState extends State<HarvestRunScreen>
    with SingleTickerProviderStateMixin {
  final HarvestRunLogic _logic = HarvestRunLogic();
  final HarvestRunData _data = HarvestRunData();
  final Random _random = Random();
  final GardenAudioService _audio = GardenAudioService();

  _HarvestPhase _phase = _HarvestPhase.intro;
  HarvestLevelConfig? _config;
  final List<HarvestFieldTile> _tiles = <HarvestFieldTile>[];

  int _maxUnlocked = 1;
  int _sessionPoints = 0;
  int _timeLeft = 0;
  int _orderIndex = 0;
  /// Required crops for the current order (until delivered).
  final Map<HarvestCrop, int> _orderBaseline = <HarvestCrop, int>{};
  /// Crops collected in the delivery basket before tapping Deliver.
  final Map<HarvestCrop, int> _gatherBasket = <HarvestCrop, int>{};
  /// Harvest order for restoring tiles on a failed delivery.
  final List<int> _basketHarvestSlots = <int>[];
  int _patienceLeft = 0;
  int _picksScore = 0;
  int _penaltySum = 0;
  int _picksDone = 0;

  bool _gameActive = false;
  bool _paused = false;
  bool _showIntro = true;

  Timer? _tickTimer;
  String? _userId;

  /// One visual basket slot per order; active slot receives harvest flight.
  List<GlobalKey> _basketKeys = <GlobalKey>[];
  /// One key per crop patch (single field block).
  final Map<HarvestCrop, GlobalKey> _patchKeys = <HarvestCrop, GlobalKey>{};
  final GlobalKey _gatherBasketKey = GlobalKey(debugLabel: 'gather_basket');
  final GlobalKey _orderCardKey = GlobalKey(debugLabel: 'order_card_target');
  final GlobalKey _scorePillKey = GlobalKey(debugLabel: 'score_pill');
  OverlayEntry? _flightEntry;
  OverlayEntry? _scoreFloatEntry;
  bool _deliverBusy = false;

  /// Tractor passes along the lane below the patch grid.
  late final AnimationController _tractorPassCtrl;

  @override
  void initState() {
    super.initState();
    _tractorPassCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    unawaited(_audio.init());
    unawaited(_loadMeta());
  }

  Future<void> _loadMeta() async {
    final Map<String, dynamic>? user = await _data.getCurrentUser();
    final int u = await _data.loadMaxUnlockedLevel();
    if (!mounted) return;
    setState(() {
      _userId = user?['uid'] as String?;
      _maxUnlocked = u.clamp(1, HarvestRunData.levels.length);
    });
  }

  @override
  void dispose() {
    _tractorPassCtrl.dispose();
    _scoreFloatEntry?.remove();
    _scoreFloatEntry = null;
    _flightEntry?.remove();
    _flightEntry = null;
    _tickTimer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _refreshPatchKeys() {
    final Set<HarvestCrop> present = <HarvestCrop>{};
    for (final HarvestFieldTile t in _tiles) {
      present.add(t.crop);
    }
    _patchKeys.removeWhere((HarvestCrop k, _) => !present.contains(k));
    for (final HarvestCrop k in present) {
      _patchKeys.putIfAbsent(
        k,
        () => GlobalKey(debugLabel: 'patch_${k.name}'),
      );
    }
  }

  void _insertHarvestFlight(Offset start, Offset end, String emoji) {
    _flightEntry?.remove();
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _HarvestFlightParticle(
        start: start,
        end: end,
        emoji: emoji,
        onDone: () {
          entry.remove();
          if (_flightEntry == entry) {
            _flightEntry = null;
          }
        },
      ),
    );
    _flightEntry = entry;
    overlay.insert(entry);
  }

  void _resetBasketForOrder(HarvestBasketOrder o) {
    _orderBaseline.clear();
    for (final MapEntry<HarvestCrop, int> e in o.need.entries) {
      if (e.value > 0) {
        _orderBaseline[e.key] = e.value;
      }
    }
    _gatherBasket.clear();
    _basketHarvestSlots.clear();
  }

  int _gatherBasketItemCount() {
    int s = 0;
    for (final int n in _gatherBasket.values) {
      s += n;
    }
    return s;
  }

  bool _gatherBasketIsEmpty() => _gatherBasketItemCount() == 0;

  bool _deliverMatchesOrderBaseline() {
    for (final MapEntry<HarvestCrop, int> e in _orderBaseline.entries) {
      if ((_gatherBasket[e.key] ?? 0) != e.value) {
        return false;
      }
    }
    for (final MapEntry<HarvestCrop, int> e in _gatherBasket.entries) {
      if (e.value > 0 && (_orderBaseline[e.key] ?? 0) != e.value) {
        return false;
      }
    }
    return !_gatherBasketIsEmpty();
  }

  int _netRoundScore(HarvestLevelConfig c) {
    final int gross = _picksScore - _penaltySum;
    return gross.clamp(-999999, 999999);
  }

  int _starsForRound(HarvestLevelConfig c, int timeLeft) {
    final double ratio =
        c.seconds > 0 ? (timeLeft / c.seconds).clamp(0.0, 1.0) : 0.0;
    if (ratio >= 0.42) return 3;
    if (ratio >= 0.22) return 2;
    return 1;
  }

  /// Builds tiles from merged needs of orders [startOrderIndex] … end (decoys fill [fieldSize]).
  void _regenerateField(HarvestLevelConfig c, {int startOrderIndex = 0}) {
    final Map<HarvestCrop, int> need = <HarvestCrop, int>{};
    for (int oi = startOrderIndex; oi < c.orders.length; oi++) {
      for (final MapEntry<HarvestCrop, int> e in c.orders[oi].need.entries) {
        need[e.key] = (need[e.key] ?? 0) + e.value;
      }
    }
    final List<HarvestCrop> pool = <HarvestCrop>[];
    for (final MapEntry<HarvestCrop, int> e in need.entries) {
      for (int i = 0; i < e.value; i++) {
        pool.add(e.key);
      }
    }
    while (pool.length < c.fieldSize) {
      pool.add(HarvestCrop.values[_random.nextInt(HarvestCrop.values.length)]);
    }
    pool.shuffle(_random);
    _tiles
      ..clear()
      ..addAll(
        List<HarvestFieldTile>.generate(
          pool.length,
          (int i) => HarvestFieldTile(slotIndex: i, crop: pool[i]),
        ),
      );
    _refreshPatchKeys();
  }

  void _startLevel(HarvestLevelConfig c, {bool playAdvanceCue = false}) {
    _tickTimer?.cancel();
    _regenerateField(c);
    _basketKeys = List<GlobalKey>.generate(
      c.orders.length,
      (int i) => GlobalKey(debugLabel: 'harvest_basket_$i'),
    );
    final HarvestBasketOrder first = c.orders.first;
    setState(() {
      _config = c;
      _phase = _HarvestPhase.playing;
      _gameActive = true;
      _paused = false;
      _timeLeft = c.seconds;
      _orderIndex = 0;
      _picksScore = 0;
      _penaltySum = 0;
      _picksDone = 0;
      _resetBasketForOrder(first);
      _patienceLeft = first.patienceSeconds;
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    if (playAdvanceCue) {
      unawaited(_audio.playLevelUp());
    }
    unawaited(_audio.playRoundStart());
    if (!_tractorPassCtrl.isAnimating) {
      _tractorPassCtrl.repeat();
    }
  }

  void _onTick() {
    if (!mounted || !_gameActive || _paused) return;
    final HarvestLevelConfig? c = _config;
    if (c == null) return;
    final int before = _timeLeft;
    setState(() {
      _timeLeft -= 1;
      if (_timeLeft < 0) _timeLeft = 0;
      if (_patienceLeft > 0) {
        _patienceLeft -= 1;
        if (_patienceLeft < 0) _patienceLeft = 0;
      }
    });
    if (before > 10 && _timeLeft <= 10 && _timeLeft > 0) {
      unawaited(_audio.playTimerWarning());
    }
    if (_timeLeft <= 0) {
      unawaited(_finishRound(won: false));
      return;
    }
    if (_patienceLeft <= 0 && _gameActive) {
      unawaited(_finishRound(won: false));
      return;
    }
  }

  Future<void> _finishRound({required bool won}) async {
    if (!_gameActive) return;
    _tractorPassCtrl.stop();
    _gameActive = false;
    _tickTimer?.cancel();
    _tickTimer = null;
    if (!mounted) return;

    final HarvestLevelConfig c = _config!;
    final int timeSnap = _timeLeft.clamp(0, c.seconds);
    final int patienceSnap = _patienceLeft;
    final int bonus =
        won ? c.completionBonus + timeSnap * c.timeBonusPerSecondLeft : 0;
    final int net = won ? (_netRoundScore(c) + bonus).clamp(0, 999999) : 0;
    final int stars = won ? _starsForRound(c, timeSnap) : 0;

    int awardMeta = 0;
    if (won) {
      awardMeta =
          4 + stars * 2 + (c.id ~/ 2) + (net ~/ 14).clamp(0, 24);
      setState(() => _sessionPoints += awardMeta);
      final int nextId = c.id + 1;
      if (nextId <= HarvestRunData.levels.length) {
        await _data.saveMaxUnlockedLevel(nextId);
        if (mounted) {
          final int u = await _data.loadMaxUnlockedLevel();
          setState(() => _maxUnlocked = u);
        }
      }
      unawaited(_audio.playLevelComplete());
    } else {
      unawaited(_audio.playGameOver());
    }

    if (won && _userId != null) {
      await _data.saveScoreToFirebase(
        _userId!,
        awardMeta,
        c.totalPicksAllOrders,
        c.totalPicksAllOrders,
        true,
        'H${c.id}: ${c.title}',
        timeSnap,
        levelId: c.id,
      );
    } else if (!won && _userId != null) {
      await _data.saveScoreToFirebase(
        _userId!,
        0,
        _picksDone,
        c.totalPicksAllOrders,
        false,
        'H${c.id}: ${c.title}',
        timeSnap,
        levelId: c.id,
      );
    }

    if (!mounted) return;

    final bool hasNext = c.id < HarvestRunData.levels.length;
    await _showRoundDialog(
      won: won,
      title: won
          ? (hasNext
              ? 'Stage ${c.id} cleared — next: Round ${c.id + 1}'
              : 'All stages cleared!')
          : (timeSnap <= 0
              ? "Time's up"
              : (patienceSnap <= 0
                  ? 'Order patience ran out'
                  : 'Order incomplete')),
      subtitle: '${c.title} · ${c.orders.length} orders',
      netPoints: net,
      awardMeta: awardMeta,
      stars: stars,
      timeLeft: timeSnap,
      timeTotal: c.seconds,
      hasNext: hasNext,
    );

    if (!mounted) return;

    if (won) {
      if (hasNext) {
        final HarvestLevelConfig? nxt = HarvestRunData.levelById(c.id + 1);
        if (nxt != null) {
          _startLevel(nxt, playAdvanceCue: true);
          return;
        }
      }
      _startLevel(HarvestRunData.levels.first);
      return;
    }
    _startLevel(c);
  }

  Future<void> _showRoundDialog({
    required bool won,
    required String title,
    required String subtitle,
    required int netPoints,
    required int awardMeta,
    required int stars,
    required int timeLeft,
    required int timeTotal,
    required bool hasNext,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF1E2A3A).withValues(alpha: 0.88),
                    const Color(0xFF26364A).withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.26),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF8FBFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFDCE6F2).withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  if (won) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(3, (int i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star_rounded,
                            size: 30,
                            color: i < stars
                                ? const Color(0xFFFFD166)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        );
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    won ? '$netPoints' : '—',
                    style: const TextStyle(
                      color: Color(0xFFFFD166),
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    won ? 'Round score' : 'Try again',
                    style: const TextStyle(
                      color: Color(0xFFDCE6F2),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Session: $_sessionPoints pts',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD166),
                        foregroundColor: const Color(0xFF2A3A4F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        won
                            ? (hasNext ? 'Continue' : 'Play again from round 1')
                            : 'Retry this round',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTileTap(HarvestFieldTile tile) {
    final HarvestLevelConfig? c = _config;
    if (c == null || !_gameActive || _paused || tile.harvested) return;

    Offset? start;
    Offset? end;
    final BuildContext? ctxPatch = _patchKeys[tile.crop]?.currentContext;
    final BuildContext? ctxGather = _gatherBasketKey.currentContext;
    final RenderBox? overlayRb =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (ctxPatch != null &&
        ctxGather != null &&
        overlayRb != null &&
        overlayRb.attached) {
      final RenderBox? tbox = ctxPatch.findRenderObject() as RenderBox?;
      final RenderBox? gbox = ctxGather.findRenderObject() as RenderBox?;
      if (tbox != null &&
          gbox != null &&
          tbox.attached &&
          gbox.attached) {
        start = tbox.localToGlobal(
          tbox.size.center(Offset.zero),
          ancestor: overlayRb,
        );
        end = gbox.localToGlobal(
          gbox.size.center(Offset.zero),
          ancestor: overlayRb,
        );
      }
    }

    setState(() {
      tile.harvested = true;
      _gatherBasket[tile.crop] = (_gatherBasket[tile.crop] ?? 0) + 1;
      _basketHarvestSlots.add(tile.slotIndex);
    });
    if (start != null && end != null) {
      _insertHarvestFlight(start, end, tile.crop.emoji);
    }
    HapticFeedback.mediumImpact();
    unawaited(_audio.playToolGrab());
  }

  Future<void> _onDeliverPressed() async {
    final HarvestLevelConfig? c = _config;
    if (c == null || !_gameActive || _paused || _deliverBusy) {
      return;
    }
    if (_gatherBasketIsEmpty()) {
      _snack('Fill the basket from the fields first.');
      return;
    }
    setState(() => _deliverBusy = true);

    Offset? start;
    Offset? end;
    final BuildContext? ctxG = _gatherBasketKey.currentContext;
    final BuildContext? ctxO = _orderCardKey.currentContext;
    final RenderBox? overlayRb =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (ctxG != null &&
        ctxO != null &&
        overlayRb != null &&
        overlayRb.attached) {
      final RenderBox? gb = ctxG.findRenderObject() as RenderBox?;
      final RenderBox? ob = ctxO.findRenderObject() as RenderBox?;
      if (gb != null &&
          ob != null &&
          gb.attached &&
          ob.attached) {
        start = gb.localToGlobal(
          gb.size.center(Offset.zero),
          ancestor: overlayRb,
        );
        end = ob.localToGlobal(
          ob.size.topCenter(Offset.zero) + const Offset(0, 18),
          ancestor: overlayRb,
        );
      }
    }

    final List<String> flyEmojis = <String>[];
    for (final MapEntry<HarvestCrop, int> e in _gatherBasket.entries) {
      for (int i = 0; i < e.value; i++) {
        flyEmojis.add(e.key.emoji);
      }
    }
    if (start != null && end != null) {
      final String bundle =
          flyEmojis.isEmpty ? '🧺' : flyEmojis.take(8).join();
      _insertHarvestFlight(start, end, bundle);
    }
    await Future<void>.delayed(const Duration(milliseconds: 560));
    if (!mounted) {
      return;
    }

    final bool ok = _deliverMatchesOrderBaseline();
    if (ok) {
      final int n = _gatherBasketItemCount();
      final int pts = n * c.pointsPerPick;
      setState(() {
        _picksScore += pts;
        _picksDone += n;
        _gatherBasket.clear();
        _basketHarvestSlots.clear();
      });
      _showScoreFloat(pts, positive: true);
      HapticFeedback.heavyImpact();
      unawaited(_audio.playLevelUp());
      _onCurrentOrderComplete();
    } else {
      final int pen =
          c.uselessTapPenalty * max(2, _gatherBasketItemCount());
      setState(() {
        _penaltySum += pen;
        for (final int slot in _basketHarvestSlots) {
          for (final HarvestFieldTile t in _tiles) {
            if (t.slotIndex == slot) {
              t.harvested = false;
              break;
            }
          }
        }
        _basketHarvestSlots.clear();
        _gatherBasket.clear();
      });
      _showScoreFloat(-pen, positive: false);
      HapticFeedback.vibrate();
      unawaited(_audio.playWeedWaste());
      _snack('Wrong basket — crops returned to the field. −$pen pts');
    }
    if (mounted) {
      setState(() => _deliverBusy = false);
    }
  }

  void _showScoreFloat(int delta, {required bool positive}) {
    _scoreFloatEntry?.remove();
    final OverlayState? overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }
    final BuildContext? scoreCtx = _scorePillKey.currentContext;
    final RenderBox? overlayRb =
        overlay.context.findRenderObject() as RenderBox?;
    Offset target = Offset.zero;
    if (scoreCtx != null &&
        overlayRb != null &&
        scoreCtx.findRenderObject() is RenderBox) {
      final RenderBox sb = scoreCtx.findRenderObject()! as RenderBox;
      if (sb.attached) {
        target = sb.localToGlobal(
          sb.size.center(Offset.zero),
          ancestor: overlayRb,
        );
      }
    }
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) => _HarvestScoreFloater(
        delta: delta,
        positive: positive,
        target: target,
        onDone: () {
          entry.remove();
          if (_scoreFloatEntry == entry) {
            _scoreFloatEntry = null;
          }
        },
      ),
    );
    _scoreFloatEntry = entry;
    overlay.insert(entry);
  }

  void _onPatchTap(HarvestCrop crop) {
    HarvestFieldTile? target;
    for (final HarvestFieldTile t in _tiles) {
      if (t.crop == crop && !t.harvested) {
        target = t;
        break;
      }
    }
    if (target == null) {
      return;
    }
    _onTileTap(target);
  }

  void _onCurrentOrderComplete() {
    final HarvestLevelConfig? c = _config;
    if (c == null || !_gameActive) return;
    if (_orderIndex + 1 >= c.orders.length) {
      unawaited(_finishRound(won: true));
      return;
    }
    setState(() {
      _orderIndex++;
      final HarvestBasketOrder next = c.orders[_orderIndex];
      _resetBasketForOrder(next);
      _patienceLeft = next.patienceSeconds;
      _regenerateField(c, startOrderIndex: _orderIndex);
      _basketKeys = List<GlobalKey>.generate(
        c.orders.length,
        (int i) => GlobalKey(debugLabel: 'harvest_basket_$i'),
      );
    });
    unawaited(_audio.playLevelUp());
    _snack('Delivered! Next: ${c.orders[_orderIndex].title}');
  }

  void _snack(String msg) {
    if (!mounted) return;
    final ScaffoldMessengerState ms = ScaffoldMessenger.of(context);
    ms.hideCurrentSnackBar();
    ms.showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1600),
      ),
    );
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      unawaited(_audio.playPause());
    } else {
      unawaited(_audio.playResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1814),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: Lottie.asset(
              'assets/animations/Animation_background.json',
              fit: BoxFit.cover,
              repeat: true,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    const Color(0xFF0A120E).withValues(alpha: 0.55),
                    const Color(0xFF152A1E).withValues(alpha: 0.42),
                    const Color(0xFF0D160F).withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildTopBar(context),
                Expanded(
                  child: _phase == _HarvestPhase.playing && _config != null
                      ? KeyedSubtree(
                          key: ValueKey<int>(_config!.id),
                          child: _buildPlayfield(),
                        )
                      : (_showIntro
                          ? _buildIntro()
                          : const Center(child: CircularProgressIndicator())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final bool playing =
        _phase == _HarvestPhase.playing && _config != null;
    if (playing) {
      final HarvestLevelConfig c = _config!;
      final double progress = HarvestRunData.levels.isEmpty
          ? 0.0
          : (c.id / HarvestRunData.levels.length).clamp(0.0, 1.0);
      final int netPreview = _netRoundScore(c);

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                _glassExit(context),
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: <Widget>[
                        _pillTimer(),
                        _pillScore(netPreview),
                        _miniIcon(
                          icon: _paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          onTap: _togglePause,
                          tip: _paused ? 'Resume' : 'Pause',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 0.8,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor:
                        const Color(0xFF1E293B).withValues(alpha: 0.32),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF22C55E),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    'STAGE ${c.id} / ${HarvestRunData.levels.length}',
                    style: const TextStyle(
                      color: Color(0xFFF8FBFF),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            if (_timeLeft > 0 && _timeLeft <= 12)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '⏱ $_timeLeft s left',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _timeLeft <= 5
                        ? const Color(0xFFFFAB91)
                        : const Color(0xFFFFE082),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                c.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              'Basket ${_orderIndex + 1}/${c.orders.length}  ·  Picks $_picksDone/${c.totalPicksAllOrders}  ·  −$_penaltySum penalty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: <Widget>[
          _glassExit(context),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Harvest Run',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassExit(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_gameActive) {
          unawaited(_audio.playButtonTap());
          _logic.showExitDialog(context, () {
            _tickTimer?.cancel();
            Navigator.pop(context);
          });
        } else {
          Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.34),
              Colors.white.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        ),
        child: const Icon(Icons.exit_to_app_rounded,
            color: Color(0xFFF8FBFF), size: 22),
      ),
    );
  }

  Widget _pillTimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFF0EA5E9).withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.timer_outlined, color: Color(0xFFF8FBFF), size: 18),
          const SizedBox(width: 6),
          Text(
            _logic.formatTime(_timeLeft),
            style: const TextStyle(
              color: Color(0xFFF8FBFF),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillScore(int netPreview) {
    return Container(
      key: _scorePillKey,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            const Color(0xFFF59E0B).withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.workspace_premium_rounded,
              color: Color(0xFFFFF8DE), size: 18),
          const SizedBox(width: 6),
          Text(
            '$netPreview',
            style: const TextStyle(
              color: Color(0xFFFFF8DE),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniIcon({
    required IconData icon,
    required VoidCallback onTap,
    required String tip,
  }) {
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    final HarvestLevelConfig first = HarvestRunData.levels.first;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                const Color(0xFF2D3F55).withValues(alpha: 0.9),
                const Color(0xFF3A5068).withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              const Text('🧺', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 12),
              const Text(
                'Harvest Run',
                style: TextStyle(
                  color: Color(0xFFF8FBFF),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Several basket orders per round — pick the right rows, fill counts, beat each order timer and the big clock.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFDCE6F2).withValues(alpha: 0.95),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Text(
                  HarvestRunData.missionBrief(first),
                  style: const TextStyle(
                    color: Color(0xFFDCE6F2),
                    fontSize: 12.5,
                    height: 1.42,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Best stage unlocked: $_maxUnlocked / ${HarvestRunData.levels.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showIntro = false;
                    _sessionPoints = 0;
                  });
                  _startLevel(HarvestRunData.levels.first);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD166),
                  foregroundColor: const Color(0xFF2A3A4F),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'START',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayfield() {
    final HarvestLevelConfig c = _config!;
    final Map<HarvestCrop, List<HarvestFieldTile>> grouped =
        <HarvestCrop, List<HarvestFieldTile>>{};
    for (final HarvestFieldTile t in _tiles) {
      grouped.putIfAbsent(t.crop, () => <HarvestFieldTile>[]).add(t);
    }
    final List<HarvestCrop> patchOrder = HarvestCrop.values
        .where((HarvestCrop k) => (grouped[k]?.isNotEmpty ?? false))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _orderBasketsStrip(c),
          const SizedBox(height: 8),
          _orderCard(c),
          const SizedBox(height: 8),
          _gatherBasketAndDeliver(c),
          const SizedBox(height: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder:
                      (BuildContext context, BoxConstraints constraints) {
                    return _harvestPatchesLand(
                      patchOrder,
                      grouped,
                      constraints,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small square crop blocks with wider street gaps; no scroll.
  Widget _harvestPatchesLand(
    List<HarvestCrop> patchOrder,
    Map<HarvestCrop, List<HarvestFieldTile>> grouped,
    BoxConstraints lc,
  ) {
    final int n = patchOrder.length;
    if (n == 0) {
      return const SizedBox.expand();
    }
    const double pad = 10;
    const double street = 20;
    const double tractorLaneH = 52;
    final double maxW = lc.maxWidth - pad * 2;
    final double maxH =
        lc.maxHeight - pad * 2 - (_gameActive ? tractorLaneH : 0);

    int cols;
    if (n == 1) {
      cols = 1;
    } else if (n == 2) {
      cols = 2;
    } else if (n <= 4) {
      cols = 2;
    } else {
      cols = 3;
    }
    final int rows = (n + cols - 1) ~/ cols;

    double sideW = (maxW - (cols - 1) * street) / cols;
    double sideH = (maxH - (rows - 1) * street) / rows;
    final double side = min(sideW, sideH).clamp(48.0, 104.0);

    final List<Widget> bandRows = <Widget>[];
    int idx = 0;
    for (int r = 0; r < rows; r++) {
      final int inRow = min(cols, n - idx);
      final List<Widget> rowChildren = <Widget>[];
      for (int c = 0; c < inRow; c++) {
        if (c > 0) {
          rowChildren.add(
            Container(
              width: street,
              alignment: Alignment.center,
              child: Container(
                width: 4,
                height: side * 0.85,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }
        final HarvestCrop crop = patchOrder[idx];
        final List<HarvestFieldTile> tiles = grouped[crop]!;
        final GlobalKey? pk = _patchKeys[crop];
        idx++;
        if (pk == null) {
          continue;
        }
        rowChildren.add(
          _HarvestPatchSquare(
            crop: crop,
            tiles: tiles,
            patchKey: pk,
            onTapPatch: _onPatchTap,
            side: side,
          ),
        );
      }
      bandRows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: rowChildren,
        ),
      );
      if (r < rows - 1) {
        bandRows.add(
          SizedBox(
            height: street,
            child: Center(
              child: Container(
                height: 4,
                width: min(maxW, cols * side + (cols - 1) * street),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        );
      }
    }

    final Widget farmBlock = Padding(
      padding: const EdgeInsets.all(pad),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: bandRows,
          ),
        ),
      ),
    );

    const double tractorW = 44;
    const double tractorH = 34;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(child: farmBlock),
        if (_gameActive)
          SizedBox(
            height: tractorLaneH,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          const Color(0xFF4A3528).withValues(alpha: 0.6),
                          const Color(0xFF1A1008).withValues(alpha: 0.85),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _tractorPassCtrl,
                    builder: (BuildContext context, Widget? child) {
                      final double laneW = lc.maxWidth;
                      final double t = _tractorPassCtrl.value;
                      final double u = (sin(2 * pi * t - pi / 2) + 1) / 2;
                      final double x = -tractorW + u * (laneW + 2 * tractorW);
                      final bool faceRight = cos(2 * pi * t) >= 0;
                      return Positioned(
                        left: x,
                        top: (tractorLaneH - tractorH) * 0.5,
                        width: tractorW,
                        height: tractorH,
                        child: Transform.scale(
                          scaleX: faceRight ? 1 : -1,
                          alignment: Alignment.center,
                          child: Lottie.asset(
                            'assets/animations/tractor.json',
                            fit: BoxFit.contain,
                            repeat: true,
                            animate: !_paused,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _gatherBasketAndDeliver(HarvestLevelConfig c) {
    final List<String> icons = <String>[];
    for (final MapEntry<HarvestCrop, int> e in _gatherBasket.entries) {
      for (int i = 0; i < e.value; i++) {
        icons.add(e.key.emoji);
      }
    }
    final bool canDeliver =
        !_gatherBasketIsEmpty() && !_deliverBusy && _gameActive && !_paused;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: RepaintBoundary(
            key: _gatherBasketKey,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF5C3D1E).withValues(alpha: 0.88),
                    const Color(0xFF2D1A0E).withValues(alpha: 0.94),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.55),
                  width: 1.4,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.shopping_basket_rounded,
                    color: Color(0xFFFFE7B8),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: icons.isEmpty
                        ? Text(
                            'Tap fields to fill the basket…',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          )
                        : Wrap(
                            spacing: 3,
                            runSpacing: 3,
                            children: icons
                                .map(
                                  (String em) => Text(
                                    em,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 108,
          height: 48,
          child: FilledButton(
            onPressed: canDeliver ? () => unawaited(_onDeliverPressed()) : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: const Color(0xFF052E16),
              disabledBackgroundColor: Colors.white24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _deliverBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF052E16),
                    ),
                  )
                : const Text(
                    'Deliver',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _orderCard(HarvestLevelConfig c) {
    final HarvestBasketOrder o = c.orders[_orderIndex];

    return ClipRRect(
      key: _orderCardKey,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.1),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFFFFD166), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    o.title,
                    style: const TextStyle(
                      color: Color(0xFFFFF8E8),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'Order ${_orderIndex + 1}/${c.orders.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: o.need.entries
                  .where((MapEntry<HarvestCrop, int> e) => e.value > 0)
                  .map((MapEntry<HarvestCrop, int> e) {
                final int total = e.value;
                final int inBasket = _gatherBasket[e.key] ?? 0;
                final int done = inBasket.clamp(0, total);
                return _OrderChip(
                  crop: e.key,
                  total: total,
                  done: done,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// One basket widget per order; active shows patience bar.
  Widget _orderBasketsStrip(HarvestLevelConfig c) {
    if (_basketKeys.length != c.orders.length) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: c.orders.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int i) {
          final HarvestBasketOrder o = c.orders[i];
          final bool done = i < _orderIndex;
          final bool active = i == _orderIndex;
          final bool pending = i > _orderIndex;
          final int pMax = o.patienceSeconds.clamp(1, 9999);
          final double pVal =
              active ? (_patienceLeft / pMax).clamp(0.0, 1.0) : 0.0;
          final int needSum =
              o.need.values.fold<int>(0, (int a, int b) => a + b);
          int leftSum = 0;
          if (active) {
            for (final MapEntry<HarvestCrop, int> e in o.need.entries) {
              if (e.value <= 0) {
                continue;
              }
              leftSum += max(
                0,
                e.value - (_gatherBasket[e.key] ?? 0),
              );
            }
          } else if (done) {
            leftSum = 0;
          } else {
            leftSum = needSum;
          }
          final int inBasket = needSum - leftSum;

          final List<Widget> chipRow = <Widget>[];
          if (!pending) {
            for (final MapEntry<HarvestCrop, int> e
                in o.need.entries.where(
                    (MapEntry<HarvestCrop, int> x) => x.value > 0)) {
              final int total = e.value;
              final int left = active
                  ? max(0, e.value - (_gatherBasket[e.key] ?? 0))
                  : 0;
              final int got = (total - left).clamp(0, total);
              final int repeat = min(4, got);
              if (repeat <= 0) {
                continue;
              }
              chipRow.add(
                Opacity(
                  opacity: done ? 0.55 : 1,
                  child: Text(
                    List<String>.filled(repeat, e.key.emoji).join(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            }
          }

          final Color frame = done
              ? const Color(0xFF4ADE80).withValues(alpha: 0.55)
              : active
                  ? const Color(0xFFFFD166)
                  : Colors.white.withValues(alpha: 0.28);
          final double frameW = active ? 2.4 : 1.2;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: active ? 120 : 100,
            child: Container(
              key: _basketKeys[i],
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: done
                      ? <Color>[
                          const Color(0xFF14532D).withValues(alpha: 0.75),
                          const Color(0xFF052E16).withValues(alpha: 0.88),
                        ]
                      : pending
                          ? <Color>[
                              Colors.black.withValues(alpha: 0.45),
                              Colors.black.withValues(alpha: 0.62),
                            ]
                          : <Color>[
                              const Color(0xFF5C3D1E).withValues(alpha: 0.88),
                              const Color(0xFF3D2914).withValues(alpha: 0.94),
                            ],
                ),
                border: Border.all(color: frame, width: frameW),
                boxShadow: active
                    ? <BoxShadow>[
                        BoxShadow(
                          color: const Color(0xFFFFD166)
                              .withValues(alpha: 0.35),
                          blurRadius: 18,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : pending
                                ? Icons.lock_outline_rounded
                                : Icons.shopping_basket_rounded,
                        size: 18,
                        color: done
                            ? const Color(0xFFBBF7D0)
                            : pending
                                ? Colors.white54
                                : const Color(0xFFFFE7B8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '#${i + 1}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (pending)
                    Expanded(
                      child: Center(
                        child: Text(
                          '…',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            done
                                ? '✓'
                                : '$inBasket / $needSum',
                            style: TextStyle(
                              color: done
                                  ? const Color(0xFFBBF7D0)
                                  : const Color(0xFFFFE8B8),
                              fontWeight: FontWeight.w900,
                              fontSize: done ? 28 : 15,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!pending && chipRow.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 2,
                      runSpacing: 2,
                      children: chipRow,
                    ),
                  if (active) ...<Widget>[
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 11,
                          color: _patienceLeft <= 8
                              ? const Color(0xFFFFAB91)
                              : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_patienceLeft}s',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: _patienceLeft <= 8
                                ? const Color(0xFFFFAB91)
                                : const Color(0xFFFFD166),
                          ),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pVal,
                        minHeight: 5,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _patienceLeft <= 8
                              ? const Color(0xFFFB7185)
                              : const Color(0xFF4ADE80),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HarvestScoreFloater extends StatefulWidget {
  const _HarvestScoreFloater({
    required this.delta,
    required this.positive,
    required this.target,
    required this.onDone,
  });

  final int delta;
  final bool positive;
  final Offset target;
  final VoidCallback onDone;

  @override
  State<_HarvestScoreFloater> createState() => _HarvestScoreFloaterState();
}

class _HarvestScoreFloaterState extends State<_HarvestScoreFloater>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward().then((_) {
      if (mounted) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox.expand(
          child: AnimatedBuilder(
            animation: _curve,
            builder: (BuildContext context, Widget? child) {
              final double t = _curve.value;
              final String label =
                  widget.delta > 0 ? '+${widget.delta}' : '${widget.delta}';
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: widget.target.dx - 48,
                    top: widget.target.dy - 36 - 72 * t,
                    child: Opacity(
                      opacity: (1 - t * 0.92).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: lerpDouble(1.15, 0.85, t)!,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: widget.positive
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFFB7185),
                            shadows: const <Shadow>[
                              Shadow(
                                blurRadius: 10,
                                color: Color(0x88000000),
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HarvestFlightParticle extends StatefulWidget {
  const _HarvestFlightParticle({
    required this.start,
    required this.end,
    required this.emoji,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final String emoji;
  final VoidCallback onDone;

  @override
  State<_HarvestFlightParticle> createState() => _HarvestFlightParticleState();
}

class _HarvestFlightParticleState extends State<_HarvestFlightParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 580),
    );
    _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _ctrl.forward().then((_) {
      if (mounted) {
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double half = 22;
    return AnimatedBuilder(
      animation: _curve,
      builder: (BuildContext context, Widget? child) {
        final double t = _curve.value;
        final double u = 1.0 - t;
        final Offset c = Offset(
          (widget.start.dx + widget.end.dx) * 0.5,
          min(widget.start.dy, widget.end.dy) - 88,
        );
        final Offset pos = Offset(
          u * u * widget.start.dx + 2 * u * t * c.dx + t * t * widget.end.dx,
          u * u * widget.start.dy + 2 * u * t * c.dy + t * t * widget.end.dy,
        );
        final double scale = lerpDouble(1.08, 0.58, t)!;
        final int glyphCount = widget.emoji.length;
        final double fontPx =
            (40 / (1 + max(0, glyphCount - 1) * 0.18)).clamp(14.0, 40.0);
        return IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: SizedBox.expand(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    left: pos.dx - half,
                    top: pos.dy - half,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: 1 - 0.12 * t,
                        child: Text(
                          widget.emoji,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: fontPx,
                            height: 1,
                            shadows: const <Shadow>[
                              Shadow(
                                blurRadius: 8,
                                color: Color(0x66000000),
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderChip extends StatelessWidget {
  const _OrderChip({
    required this.crop,
    required this.total,
    required this.done,
  });

  final HarvestCrop crop;
  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final bool complete = done >= total;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: complete
            ? const Color(0xFF166534).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.14),
        border: Border.all(
          color: complete
              ? const Color(0xFF4ADE80)
              : const Color(0xFFFFD166).withValues(alpha: 0.5),
          width: complete ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(crop.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 6),
          Text(
            '$done / $total',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// One crop field block: emoji grid only, tappable to harvest.
class _HarvestPatchSquare extends StatelessWidget {
  const _HarvestPatchSquare({
    required this.crop,
    required this.tiles,
    required this.patchKey,
    required this.onTapPatch,
    required this.side,
  });

  final HarvestCrop crop;
  final List<HarvestFieldTile> tiles;
  final GlobalKey patchKey;
  final void Function(HarvestCrop crop) onTapPatch;
  final double side;

  static const int _cols = 4;
  static const int _rows = 4;
  static const int _visCap = _cols * _rows;

  @override
  Widget build(BuildContext context) {
    final Color accent = _harvestCropAccent(crop);
    final int alive = tiles.where((HarvestFieldTile t) => !t.harvested).length;
    final int brightCount =
        alive >= _visCap ? _visCap : alive.clamp(0, _visCap);

    const double pad = 4;
    const double gap = 1.5;
    const double borderW = 1;

    return RepaintBoundary(
      key: patchKey,
      child: SizedBox(
        width: side,
        height: side,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: alive > 0 ? () => onTapPatch(crop) : null,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    const Color(0xFF4A3528).withValues(alpha: 0.75),
                    const Color(0xFF1E140C).withValues(alpha: 0.92),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.45),
                  width: borderW,
                ),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints bc) {
                  final double boxH = bc.hasBoundedHeight && bc.maxHeight.isFinite
                      ? min(bc.maxHeight, side)
                      : side;
                  final double usable =
                      (boxH - 2 * pad - 2 * borderW).clamp(0, side);
                  final double cellRaw =
                      (usable - gap * (_cols - 1)) / _cols;
                  final double cell = max(4, cellRaw.floorToDouble());
                  final double gridTotal =
                      _cols * cell + gap * (_cols - 1);

                  Widget buildCell(int index) {
                    final bool aliveField = alive > 0;
                    final bool pickedVisually =
                        aliveField && index >= brightCount;
                    final double o = !aliveField
                        ? 0.32
                        : pickedVisually
                            ? 0.52
                            : 1.0;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: accent.withValues(alpha: 0.1),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.26),
                          width: 0.6,
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Opacity(
                            opacity: o,
                            child: Text(
                              crop.emoji,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: (cell * 0.72).clamp(8.0, 22.0),
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(pad),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: gridTotal,
                          height: gridTotal,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (int r = 0; r < _rows; r++) ...<Widget>[
                                if (r > 0) const SizedBox(height: 1.5),
                                SizedBox(
                                  height: cell,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      for (int c = 0; c < _cols; c++) ...<
                                          Widget>[
                                        if (c > 0) const SizedBox(width: 1.5),
                                        SizedBox(
                                          width: cell,
                                          height: cell,
                                          child: buildCell(r * _cols + c),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
