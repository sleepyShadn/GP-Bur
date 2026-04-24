// ========== lib/presentation/watering_flowers_screen.dart ==========
import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:appforhumman/data/watering_flowers_data.dart';
import 'package:appforhumman/domain/watering_flowers_logic.dart';
import 'package:appforhumman/domain/watering_flowers_models.dart';
import 'package:appforhumman/presentation/watering/watering_garden_backdrop.dart';
import 'package:appforhumman/presentation/watering/watering_garden_lottie_assets.dart';
import 'package:appforhumman/services/garden_audio_service.dart';
import 'package:lottie/lottie.dart';

enum _WateringPhase { levelSelect, playing }

int _fieldCrossAxisCount(int n) {
  final int k = n.clamp(1, 12);
  if (k <= 2) return 2;
  if (k <= 4) return 2;
  if (k <= 6) return 3;
  if (k <= 8) return 4;
  if (k <= 9) return 3;
  if (k <= 10) return 5;
  return 4;
}

class WateringFlowersScreen extends StatefulWidget {
  const WateringFlowersScreen({super.key});

  @override
  State<WateringFlowersScreen> createState() => _WateringFlowersScreenState();
}

class _WateringFlowersScreenState extends State<WateringFlowersScreen>
    with TickerProviderStateMixin {
  final WateringFlowersLogic _logic = WateringFlowersLogic();
  final WateringFlowersData _data = WateringFlowersData();
  final Random _random = Random();
  final GardenAudioService _gardenAudio = GardenAudioService();

  _WateringPhase _phase = _WateringPhase.levelSelect;
  WateringLevelConfig? _config;
  final List<WateringPlant> _plants = [];

  int _maxUnlocked = 1;
  int _sessionPoints = 0;
  int _timeLeft = 0;
  double _waterRemaining = 0;
  bool _reduceMotion = false;
  bool _nightTint = false;

  bool _isGameActive = false;
  bool _isPaused = false;
  bool _showIntroCard = true;
  bool _isExiting = false;

  Timer? _tickTimer;
  Timer? _tapFeedbackTimer;
  Timer? _waterSprayTimer;
  int? _tapFeedbackIndex;
  int? _sprayPlantIndex;
  int _spraySeq = 0;

  /// Opened plant — water only from this close-up view.
  int? _focusedPlantIndex;

  /// Bonus water droplet (random spawn) — tap to add to the tank.
  bool _bonusWaterActive = false;
  int _bonusWaterTicksLeft = 0;
  double _bonusWaterGrant = 0;

  int _tickCount = 0;

  /// Ticks (100 ms) until next thirst wave.
  int _demandCooldownTicks = 0;

  int _pointsFromWatering = 0;
  int _uselessTapPenaltySum = 0;
  int _deadCount = 0;

  String? _userId;

  late AnimationController _swayController;

  Future<void> _initGardenAudio() async {
    await _gardenAudio.init();
    if (!mounted) return;
    await _gardenAudio.startGardenIntroRoundStartLoop();
  }

  @override
  void initState() {
    super.initState();
    _swayController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat(reverse: true);
    unawaited(_initGardenAudio());
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final user = await _data.getCurrentUser();
    final unlocked = await _data.loadMaxUnlockedLevel();
    final reduce = await _data.loadReduceMotion();
    if (!mounted) return;
    setState(() {
      _userId = user?['uid'] as String?;
      _maxUnlocked = unlocked.clamp(1, WateringFlowersData.levels.length);
      _reduceMotion = reduce;
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tapFeedbackTimer?.cancel();
    _waterSprayTimer?.cancel();
    _swayController.dispose();
    unawaited(_gardenAudio.dispose());
    super.dispose();
  }

  void _layoutPlants(WateringLevelConfig c) {
    _plants.clear();
    final colors = [
      _logic.colorFlowerPink,
      _logic.colorFlowerYellow,
      _logic.colorFlowerPurple,
    ];
    final int n = c.plantCount.clamp(2, 12);
    const double idealMin = 0.32;
    const double idealMax = 0.86;

    final List<String> assetPool = List<String>.generate(
      n,
      (int i) => WateringGardenLottieAssets
          .diversePlants[i % WateringGardenLottieAssets.diversePlants.length],
    )..shuffle(_random);

    for (int idx = 0; idx < n; idx++) {
      const double sz = 88.0;
      _plants.add(
        WateringPlant(
          id: idx,
          x: 0.5,
          y: 0.5,
          accentColor: colors[idx % colors.length],
          size: sz,
          lottieAsset: assetPool[idx % assetPool.length],
          idealMin: idealMin,
          idealMax: idealMax,
          wantsWater: true,
          wantsFertilizer: false,
          isWeed: false,
          moisture: 0.55 + _random.nextDouble() * 0.12,
        ),
      );
    }
  }

  void _resetDemandCooldown(WateringLevelConfig c) {
    final int span =
        (c.demandIntervalMaxSec - c.demandIntervalMinSec + 1).clamp(1, 120);
    final int secs = c.demandIntervalMinSec + _random.nextInt(span);
    _demandCooldownTicks = secs * 10;
  }

  void _applyRandomDemandMutation() {
    final WateringLevelConfig? cfg = _config;
    if (cfg == null) return;
    final List<int> candidates = <int>[];
    for (int i = 0; i < _plants.length; i++) {
      final WateringPlant p = _plants[i];
      if (!p.isDead && !p.awaitingWater) {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) return;
    candidates.shuffle(_random);
    final int burstUpper =
        cfg.id <= 4 ? 3 : min(6, 2 + cfg.id ~/ 2).clamp(2, 6);
    final int want = 1 + _random.nextInt(burstUpper);
    final int k = min(want, candidates.length);
    for (int j = 0; j < k; j++) {
      final WateringPlant p = _plants[candidates[j]];
      p.awaitingWater = true;
      p.patience = 1.0;
    }
  }

  int _aliveCount() {
    int n = 0;
    for (final p in _plants) {
      if (!p.isDead) n++;
    }
    return n;
  }

  bool _allDead() => _aliveCount() <= 0;

  void _openPlantFocus(int index) {
    final cfg = _config;
    if (cfg == null || !_isGameActive || _isPaused) return;
    if (index < 0 || index >= _plants.length) return;
    final WateringPlant p = _plants[index];
    if (p.isDead) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() => _focusedPlantIndex = index);
    unawaited(_gardenAudio.playPlantFocusOpen());
  }

  void _onBonusWaterTap() {
    final cfg = _config;
    if (cfg == null || !_isGameActive || _isPaused || !_bonusWaterActive) {
      return;
    }
    setState(() {
      _waterRemaining =
          (_waterRemaining + _bonusWaterGrant).clamp(0.0, cfg.waterMax);
      _bonusWaterActive = false;
      _bonusWaterTicksLeft = 0;
    });
    HapticFeedback.mediumImpact();
    unawaited(_gardenAudio.playBonusWaterPickup());
  }

  void _closePlantFocus() {
    if (_focusedPlantIndex == null) return;
    setState(() => _focusedPlantIndex = null);
  }

  void _waterPlantAt(int index) {
    final cfg = _config;
    if (cfg == null || !_isGameActive || _isPaused) return;
    if (index < 0 || index >= _plants.length) return;
    final WateringPlant p = _plants[index];
    if (p.isDead) {
      HapticFeedback.selectionClick();
      return;
    }
    if (!p.awaitingWater) {
      setState(() {
        _uselessTapPenaltySum += cfg.uselessTapPenalty;
      });
      HapticFeedback.lightImpact();
      _gardenSnack('Not thirsty right now — wait until this plant glows.');
      return;
    }
    if (_waterRemaining < cfg.waterCostPerTap * 0.5) {
      _gardenSnack('Not enough water in the tank.');
      HapticFeedback.heavyImpact();
      return;
    }

    _waterSprayTimer?.cancel();
    setState(() {
      p.awaitingWater = false;
      p.patience = 1.0;
      p.moisture = (p.moisture + 0.14).clamp(0.0, 1.0);
      _pointsFromWatering += cfg.pointsPerWater;
      _waterRemaining =
          (_waterRemaining - cfg.waterCostPerTap).clamp(0.0, cfg.waterMax);
      _tapFeedbackIndex = index;
      _spraySeq++;
      _sprayPlantIndex = index;
    });
    HapticFeedback.mediumImpact();
    unawaited(_gardenAudio.playWaterSpray());
    _tapFeedbackTimer?.cancel();
    _tapFeedbackTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() => _tapFeedbackIndex = null);
    });
    _waterSprayTimer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      setState(() => _sprayPlantIndex = null);
    });
  }

  void _startLevel(
    WateringLevelConfig c, {
    bool playAdvanceCue = false,
    bool playRoundStartSfx = true,
  }) {
    _tickTimer?.cancel();
    _layoutPlants(c);
    setState(() {
      _config = c;
      _phase = _WateringPhase.playing;
      _isGameActive = true;
      _isPaused = false;
      _timeLeft = c.seconds;
      _waterRemaining = c.waterMax;
      _tickCount = 0;
      _pointsFromWatering = 0;
      _uselessTapPenaltySum = 0;
      _deadCount = 0;
      _tapFeedbackIndex = null;
      _sprayPlantIndex = null;
      _focusedPlantIndex = null;
      _bonusWaterActive = false;
      _bonusWaterTicksLeft = 0;
      _bonusWaterGrant = 0;
    });
    _resetDemandCooldown(c);
    // First thirst wave appears soon so the player is not idle too long.
    _demandCooldownTicks = min(_demandCooldownTicks, 35);
    _tickTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _onTick());
    if (playAdvanceCue) {
      unawaited(_gardenAudio.playLevelUp());
    }
    if (playRoundStartSfx) {
      unawaited(_gardenAudio.playRoundStart());
    }
  }

  Future<void> _runStartGameFlow() async {
    await _gardenAudio.stopGardenIntroRoundStartCue();
    await _gardenAudio.startGardenCareBgm();
    if (!mounted) return;
    setState(() {
      _showIntroCard = false;
      _sessionPoints = 0;
    });
    _startLevel(
      WateringFlowersData.levels.first,
      playRoundStartSfx: false,
    );
  }

  void _onTick() {
    if (!mounted || !_isGameActive || _isPaused) return;
    final cfg = _config;
    if (cfg == null) return;

    _tickCount++;
    const double dt = 0.1;

    if (_tickCount % 10 == 0) {
      final int timeBefore = _timeLeft;
      setState(() {
        _timeLeft -= 1;
        if (_timeLeft < 0) _timeLeft = 0;
      });
      if (timeBefore > 10 && _timeLeft <= 10 && _timeLeft > 0) {
        unawaited(_gardenAudio.playTimerWarning());
      }
      if (_timeLeft <= 0) {
        unawaited(_finishGame(timeUp: true));
        return;
      }
    }

    bool bonusJustSpawned = false;
    setState(() {
      for (final WateringPlant p in _plants) {
        if (p.isDead || !p.awaitingWater) continue;
        p.patience -= cfg.patienceDrainPerSecond * dt;
        if (p.patience <= 0) {
          p.patience = 0;
          p.isDead = true;
          p.awaitingWater = false;
          _deadCount++;
        }
      }

      if (_demandCooldownTicks > 0) {
        _demandCooldownTicks--;
      } else {
        _applyRandomDemandMutation();
        _resetDemandCooldown(cfg);
      }

      if (_bonusWaterActive) {
        if (_focusedPlantIndex == null) {
          _bonusWaterTicksLeft--;
        }
        if (_bonusWaterTicksLeft <= 0) {
          _bonusWaterActive = false;
          _bonusWaterTicksLeft = 0;
        }
      } else if (_focusedPlantIndex == null &&
          _tickCount % 50 == 0 &&
          _waterRemaining < cfg.waterMax * 0.88) {
        if (_random.nextDouble() < 0.30) {
          _bonusWaterActive = true;
          _bonusWaterTicksLeft = 72;
          _bonusWaterGrant =
              (cfg.waterMax * (0.10 + _random.nextDouble() * 0.16))
                  .clamp(12.0, 52.0);
          bonusJustSpawned = true;
        }
      }
    });
    if (bonusJustSpawned) {
      unawaited(_gardenAudio.playBonusWaterSpawn());
    }

    if (_allDead()) {
      unawaited(_finishGame(timeUp: false));
    }
  }

  int _netRoundPoints(WateringLevelConfig cfg) {
    final int gross = _pointsFromWatering - _uselessTapPenaltySum;
    final int deadPenalty = _deadCount * cfg.pointsLostPerDeadPlant;
    return gross - deadPenalty;
  }

  int _starsForRound(WateringLevelConfig cfg, bool won, int alive) {
    if (!won) return 0;
    final int net = _netRoundPoints(cfg);
    final int cap = cfg.plantCount;
    if (alive >= cap && net >= cfg.pointsPerWater * 6) return 3;
    if (alive >= (cap * 3 ~/ 4).clamp(1, cap) &&
        net >= cfg.pointsPerWater * 3) {
      return 2;
    }
    return 1;
  }

  Future<void> _finishGame({required bool timeUp}) async {
    if (!_isGameActive) return;
    _isGameActive = false;
    _tickTimer?.cancel();
    _tickTimer = null;
    if (!mounted) return;
    setState(() {
      _bonusWaterActive = false;
      _bonusWaterTicksLeft = 0;
    });

    final cfg = _config!;
    final int alive = _aliveCount();
    final bool survived = alive >= 1;
    final bool won = timeUp && survived;
    final int netPoints = _netRoundPoints(cfg).clamp(0, 999999);
    final int stars = _starsForRound(cfg, won, alive);

    await _gardenAudio.stopGardenCareBgm();
    if (won) {
      unawaited(_gardenAudio.playLevelComplete());
    } else {
      unawaited(_gardenAudio.playGameOver());
    }

    int awardPoints = 0;
    if (won) {
      awardPoints =
          4 + stars * 2 + (cfg.id ~/ 2) + (netPoints ~/ 12).clamp(0, 28);
      setState(() {
        _sessionPoints += awardPoints;
      });
      final int nextId = cfg.id + 1;
      if (nextId <= WateringFlowersData.levels.length) {
        await _data.saveMaxUnlockedLevel(nextId);
        if (mounted) {
          final u = await _data.loadMaxUnlockedLevel();
          setState(() => _maxUnlocked = u);
        }
      }
    }

    if (won && _userId != null) {
      await _data.saveScoreToFirebase(
        _userId!,
        awardPoints,
        _pointsFromWatering ~/ max(1, cfg.pointsPerWater),
        _plants.length,
        true,
        'L${cfg.id}: ${cfg.levelTitle}',
        _timeLeft,
        levelId: cfg.id,
        stars: stars,
        waterRemainingRatio:
            cfg.waterMax > 0 ? _waterRemaining / cfg.waterMax : null,
      );
    } else if (!won && _userId != null) {
      await _data.saveScoreToFirebase(
        _userId!,
        0,
        _pointsFromWatering ~/ max(1, cfg.pointsPerWater),
        _plants.length,
        false,
        'L${cfg.id}: ${cfg.levelTitle}',
        _timeLeft,
        levelId: cfg.id,
        stars: 0,
        waterRemainingRatio:
            cfg.waterMax > 0 ? _waterRemaining / cfg.waterMax : null,
      );
    }

    if (!mounted) return;

    final bool hasNext = cfg.id < WateringFlowersData.levels.length;
    final WateringLevelConfig? nextCfg =
        hasNext ? WateringFlowersData.levelById(cfg.id + 1) : null;
    await _showRoundEndDialog(
      timeUp: timeUp,
      won: won,
      levelTitle: 'Stage ${cfg.id} · ${cfg.levelTitle}',
      pointsFromWatering: _pointsFromWatering,
      uselessPenalty: _uselessTapPenaltySum,
      deadCount: _deadCount,
      deadPenaltyEach: cfg.pointsLostPerDeadPlant,
      netPoints: netPoints,
      awardMetaPoints: won ? awardPoints : 0,
      stars: stars,
      alive: alive,
      timeLeftSec: _timeLeft,
      timeTotalSec: cfg.seconds,
      sessionTotal: _sessionPoints,
      waterRemainingPct: cfg.waterMax > 0
          ? ((_waterRemaining / cfg.waterMax) * 100).round()
          : null,
      hasNextLevel: hasNext,
      clearedStageId: cfg.id,
      nextRoundId: won && hasNext ? cfg.id + 1 : null,
      nextPlantCount: won && nextCfg != null ? nextCfg.plantCount : null,
    );

    if (!mounted) return;

    if (won) {
      if (hasNext) {
        final nxt = WateringFlowersData.levelById(cfg.id + 1);
        if (nxt != null) {
          await _gardenAudio.startGardenCareBgm();
          _startLevel(nxt, playAdvanceCue: true);
          return;
        }
      }
      await _gardenAudio.startGardenCareBgm();
      _startLevel(WateringFlowersData.levels.first);
      return;
    }
    await _gardenAudio.startGardenCareBgm();
    _startLevel(cfg);
  }

  Future<void> _showRoundEndDialog({
    required bool timeUp,
    required bool won,
    required String levelTitle,
    required int pointsFromWatering,
    required int uselessPenalty,
    required int deadCount,
    required int deadPenaltyEach,
    required int netPoints,
    required int awardMetaPoints,
    required int stars,
    required int alive,
    required int timeLeftSec,
    required int timeTotalSec,
    required int sessionTotal,
    required int? waterRemainingPct,
    required bool hasNextLevel,
    required int clearedStageId,
    int? nextRoundId,
    int? nextPlantCount,
  }) async {
    if (!mounted) return;
    final int playedSec =
        (timeTotalSec - timeLeftSec).clamp(0, timeTotalSec).toInt();
    final String headline = won
        ? (hasNextLevel && nextRoundId != null
            ? 'Stage $clearedStageId cleared — next: Round $nextRoundId'
            : 'All stages cleared — epic run!')
        : (timeUp ? "Time's up" : 'All plants wilted');
    final String buttonLabel = won ? 'Play again' : 'Retry this round';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
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
                  colors: [
                    const Color(0xFF1E2A3A).withValues(alpha: 0.88),
                    const Color(0xFF26364A).withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.26),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          won ? '🌿' : '💧',
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF8FBFF),
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.2,
                        shadows: [
                          Shadow(
                            color: Color(0x99000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      levelTitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFFDCE6F2).withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (won && nextRoundId != null && nextPlantCount != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Next round uses $nextPlantCount plants and faster thirst waves.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFD166).withValues(alpha: 0.95),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (won) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (int i) {
                          final bool on = i < stars;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.star_rounded,
                              size: 32,
                              color: on
                                  ? const Color(0xFFFFD166)
                                  : Colors.white.withValues(alpha: 0.22),
                            ),
                          );
                        }),
                      ),
                      if (awardMetaPoints > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '+$awardMetaPoints session bonus',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$netPoints',
                            style: const TextStyle(
                              color: Color(0xFFFFD166),
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          const Text(
                            'Net round score',
                            style: TextStyle(
                              color: Color(0xFFDCE6F2),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _roundEndStatChip(
                            '💧',
                            '+$pointsFromWatering',
                            'Watered',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _roundEndStatChip(
                            '💀',
                            '$deadCount',
                            'Lost',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _roundEndStatChip(
                            '🌿',
                            '$alive/${_plants.length}',
                            'Alive',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _roundEndStatChip(
                            '⏱',
                            '${playedSec}s',
                            'Played',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _roundEndStatChip(
                            '⏳',
                            '${_logic.formatTime(timeLeftSec)} / ${_logic.formatTime(timeTotalSec)}',
                            'Timer',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _roundEndStatChip(
                            '🫧',
                            waterRemainingPct != null
                                ? '$waterRemainingPct%'
                                : '—',
                            'Tank',
                          ),
                        ),
                      ],
                    ),
                    if (uselessPenalty > 0 || deadCount > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            if (uselessPenalty > 0)
                              Text(
                                'Wrong taps: −$uselessPenalty',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.orange.shade200,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (deadCount > 0)
                              Text(
                                'Lost plants penalty: $deadCount × −$deadPenaltyEach',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.shade200,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Session total: $sessionTotal pts',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFDCE6F2).withValues(alpha: 0.88),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.25),
                        ),
                        child: Text(
                          buttonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.4,
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
      ),
    );
  }

  Widget _roundEndStatChip(String emoji, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDCE6F2),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _logic.colorCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        bool localMotion = _reduceMotion;
        bool localNight = _nightTint;
        return StatefulBuilder(
          builder: (context, setModal) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Game settings',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _logic.colorEmerald)),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  subtitle: const Text('Less sway on plants (accessibility)'),
                  value: localMotion,
                  onChanged: (v) {
                    setModal(() => localMotion = v);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Calm night tint'),
                  subtitle: const Text('Slightly darker overlay on the scene'),
                  value: localNight,
                  onChanged: (v) => setModal(() => localNight = v),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    await _data.saveReduceMotion(localMotion);
                    if (!ctx.mounted) return;
                    if (!mounted) return;
                    setState(() {
                      _reduceMotion = localMotion;
                      _nightTint = localNight;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _logic.colorGreenDark),
                  child:
                      const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _togglePause() {
    final bool willPause = !_isPaused;
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _focusedPlantIndex = null;
      }
    });
    if (willPause) {
      unawaited(_gardenAudio.pauseGardenCareBgm());
      unawaited(_gardenAudio.playPause());
    } else {
      unawaited(_gardenAudio.resumeGardenCareBgm());
      unawaited(_gardenAudio.playResume());
    }
  }

  void _gardenSnack(String message) {
    if (!mounted) return;
    final ScaffoldMessengerState ms = ScaffoldMessenger.of(context);
    ms.hideCurrentSnackBar();
    ms.showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 1700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmExitGame() async {
    if (_isExiting) return;
    _isExiting = true;
    _tickTimer?.cancel();
    _tapFeedbackTimer?.cancel();
    _waterSprayTimer?.cancel();
    if (mounted) {
      setState(() {
        _isGameActive = false;
        _isPaused = false;
        _focusedPlantIndex = null;
      });
    }
    await _gardenAudio.stopGardenIntroRoundStartCue();
    await _gardenAudio.stopGardenCareBgm();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if ((_phase == _WateringPhase.playing && _config != null) ||
              _showIntroCard)
            WateringGardenMorningBackdrop(reduceMotion: _reduceMotion)
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF0EAD6),
                    _logic.colorCream,
                    const Color(0xFFE8F0E4)
                  ],
                ),
              ),
            ),
          if (_nightTint && _phase == _WateringPhase.playing)
            Container(color: Colors.indigo.shade900.withValues(alpha: 0.22)),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context),
                Expanded(
                  child: (_phase == _WateringPhase.playing && _config != null)
                      ? KeyedSubtree(
                          key: ValueKey(_config!.id),
                          child: _buildPlayfield(),
                        )
                      : (_showIntroCard
                          ? _buildIntroCard()
                          : const Center(child: CircularProgressIndicator())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final bool playing = _phase == _WateringPhase.playing && _config != null;
    final int alive = _aliveCount();
    final int total =
        _plants.isEmpty ? (_config?.plantCount ?? 8) : _plants.length;

    if (playing) {
      final WateringLevelConfig cfg = _config!;
      final double progress = WateringFlowersData.levels.isEmpty
          ? 0.0
          : (cfg.id / WateringFlowersData.levels.length).clamp(0.0, 1.0);
      final int netPreview = _netRoundPoints(cfg);

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _glassExitChip(context),
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _hudTimerPill(),
                        _hudScorePill(netPreview),
                        _hudMiniIcon(
                          icon: _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          onPressed: _togglePause,
                          tooltip: _isPaused ? 'Resume' : 'Pause',
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.48),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        'STAGE ${cfg.id} / ${WateringFlowersData.levels.length}',
                        style: TextStyle(
                          color: const Color(0xFF042A22),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.35,
                          shadows: [
                            Shadow(
                              color: Colors.white.withValues(alpha: 0.75),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_timeLeft > 0 && _timeLeft <= 18)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '⏱ Low time — $_timeLeft s',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _timeLeft <= 8
                        ? const Color(0xFFC2410C)
                        : const Color(0xFFB45309),
                    shadows: const [
                      Shadow(
                        color: Color(0xCCFFFFFF),
                        blurRadius: 4,
                        offset: Offset(0, 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          cfg.levelTitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF042A22),
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$total plants this round · $alive alive  ·  Est. net $netPreview'
                          '${cfg.id >= 5 ? "  ·  Faster thirst waves" : ""}'
                          '  ·  Tap a plant  ·  Bonus water',
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F352C).withValues(alpha: 0.92),
                            height: 1.38,
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.65),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glassExitChip(context),
          const SizedBox(width: 8),
          Expanded(child: _topBarIdleCenter()),
        ],
      ),
    );
  }

  Widget _glassExitChip(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isGameActive) {
          unawaited(_gardenAudio.playButtonTap());
          _logic.showExitDialog(
            context,
            () => unawaited(_confirmExitGame()),
          );
        } else {
          unawaited(_confirmExitGame());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.34),
              Colors.white.withValues(alpha: 0.20),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B1F3A).withValues(alpha: 0.24),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.exit_to_app_rounded,
          color: Color(0xFFF8FBFF),
          size: 22,
        ),
      ),
    );
  }

  Widget _hudTimerPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0EA5E9).withValues(alpha: 0.32),
            Colors.white.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.68),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F3A).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: Color(0xFFF8FBFF),
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _logic.formatTime(_timeLeft),
            style: const TextStyle(
              color: Color(0xFFF8FBFF),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudScorePill(int netPreview) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF59E0B).withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.68),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B1F3A).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF3C7),
                  Color(0xFFFFD166),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x73FFD166),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFF7A4A00),
              size: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$netPreview',
            style: const TextStyle(
              color: Color(0xFFFFF8DE),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudMiniIcon({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _topBarIdleCenter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Garden Care',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.96),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Calm watering session',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }

  /// Water tank strip — bottom of the play area.
  Widget _bottomWaterReserve(
    BuildContext context,
    WateringLevelConfig cfg,
    double waterRatio,
  ) {
    final int pct = (waterRatio * 100).round().clamp(0, 100);
    final double bottomPad = 10 + MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.black.withValues(alpha: 0.38),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.32),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.water_drop_rounded,
                    color: _logic.colorWaterBlue.withValues(alpha: 0.98),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Water tank',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pct%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 12,
                  value: waterRatio.clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _logic.colorWaterBlue.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introSectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFFD166),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _introBullet(String iconOrNum, String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              iconOrNum,
              style: const TextStyle(fontSize: 15, height: 1.25),
            ),
          ),
          Expanded(
            child: Text(
              line,
              style: const TextStyle(
                color: Color(0xFFDCE6F2),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2D3F55).withValues(alpha: 0.88),
                const Color(0xFF3A5068).withValues(alpha: 0.82),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.26),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Center(
                  child: Text('🌿', style: TextStyle(fontSize: 44)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Garden Care',
                style: TextStyle(
                  color: Color(0xFFF8FBFF),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Prep loop plays until START — then background music runs for the session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFDCE6F2).withValues(alpha: 0.88),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _introSectionTitle('Why play'),
              const SizedBox(height: 8),
              _introBullet('🧠', 'Short focus rounds — good for a mental reset.'),
              _introBullet('🌱', 'Gentle goal: keep plants alive until time ends.'),
              _introBullet('⭐', 'Earn points and unlock higher rounds in one run.'),
              const SizedBox(height: 14),
              _introSectionTitle('How to play'),
              const SizedBox(height: 8),
              _introBullet('1', 'Tap a plant in the field to open it up close.'),
              _introBullet('2', 'When it glows, water it before the patience bar runs out.'),
              _introBullet('3', 'Watch the water tank; grab bonus drops if they appear.'),
              _introBullet('4', 'Survive until the timer ends to clear the stage.'),
              const SizedBox(height: 12),
              Text(
                'Session starts at round 1 · Best unlocked: $_maxUnlocked / ${WateringFlowersData.levels.length}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.95),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _showSettings,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
                label: Text(
                  'Game settings (motion & tint)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  unawaited(_gardenAudio.playButtonTap());
                  unawaited(_runStartGameFlow());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD166),
                  foregroundColor: const Color(0xFF2A3A4F),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 42,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.24),
                ),
                child: const Text(
                  'START GAME',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
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
    final cfg = _config!;
    final double waterRatio = cfg.waterMax > 0
        ? (_waterRemaining / cfg.waterMax).clamp(0.0, 1.0)
        : 0.0;
    final int n = _plants.length;

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _swayController,
            builder: (context, _) {
              final double sway = _reduceMotion
                  ? 0.0
                  : sin(_swayController.value * 2 * pi) * 2.2;
              return Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final int cross = _fieldCrossAxisCount(n);
                    final int rows = (n + cross - 1) ~/ cross;
                    const double gapX = 6;
                    const double gapY = 5;
                    final double maxW = constraints.maxWidth;
                    final double maxH = constraints.maxHeight;
                    final double cellW = (maxW - (cross - 1) * gapX) / cross;
                    final double cellH = (maxH - (rows - 1) * gapY) / rows;
                    final double aspect =
                        (cellW / max(1.0, cellH)).clamp(0.52, 1.08);

                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cross,
                            crossAxisSpacing: gapX,
                            mainAxisSpacing: gapY,
                            childAspectRatio: aspect,
                          ),
                          itemCount: n,
                          itemBuilder: (BuildContext context, int i) {
                            final double swayDx =
                                sway * (i.isEven ? 1.0 : -1.0);
                            return Transform.translate(
                              offset: Offset(swayDx, 0),
                              child: _FieldPlantChip(
                                plant: _plants[i],
                                logic: _logic,
                                reduceMotion: _reduceMotion,
                                onTap: () => _openPlantFocus(i),
                              ),
                            );
                          },
                        ),
                        if (_bonusWaterActive && _focusedPlantIndex == null)
                          Positioned(
                            top: 2,
                            right: 4,
                            child: Transform.scale(
                              scale: _reduceMotion
                                  ? 1.0
                                  : 1.0 +
                                      sin(_swayController.value * 2 * pi) *
                                          0.045,
                              child: _bonusWaterFloatingChip(),
                            ),
                          ),
                        if (_focusedPlantIndex != null)
                          _buildPlantFocusOverlay(context),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        _bottomWaterReserve(context, cfg, waterRatio),
      ],
    );
  }

  Widget _bonusWaterFloatingChip() {
    final int add = _bonusWaterGrant.round();
    final int sec = (_bonusWaterTicksLeft / 10).ceil().clamp(0, 99);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onBonusWaterTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF38BDF8).withValues(alpha: 0.92),
                const Color(0xFF0EA5E9).withValues(alpha: 0.75),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFFF0FDFF),
                  size: 26,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'BONUS WATER',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      '+$add tank  ·  $sec s',
                      style: const TextStyle(
                        color: Color(0xFFFFF8DE),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlantFocusOverlay(BuildContext context) {
    final int idx = _focusedPlantIndex!;
    final WateringPlant p = _plants[idx];
    final double maxCardW = (MediaQuery.sizeOf(context).width - 28)
        .clamp(280.0, 420.0);
    final Color accent =
        Color.lerp(p.accentColor, Colors.white, 0.35)!.withValues(alpha: 0.95);
    final bool thirsty = p.awaitingWater && !p.isDead;
    const Color kInk = Color(0xFF042A22);

    TextStyle ink(double size, FontWeight w, {double h = 1.2}) {
      return TextStyle(
        color: kInk,
        fontSize: size,
        fontWeight: w,
        height: h,
        shadows: [
          Shadow(
            color: Colors.white.withValues(alpha: 0.55),
            blurRadius: 6,
          ),
        ],
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _closePlantFocus,
        child: ColoredBox(
          color: const Color(0x48091814),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: maxCardW,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: Colors.white.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _closePlantFocus,
                                    customBorder: const CircleBorder(),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            Colors.white.withValues(alpha: 0.34),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(9),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: kInk,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Watering',
                                        style: ink(11, FontWeight.w800, h: 1.0)
                                            .copyWith(letterSpacing: 1.0),
                                      ),
                                      Text(
                                        'Plant ${idx + 1} of ${_plants.length}',
                                        style: ink(18, FontWeight.w800,
                                            h: 1.15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        thirsty
                                            ? 'Needs water — sprayer or tap plant'
                                            : 'Comfortable — tap outside to leave',
                                        style: TextStyle(
                                          color: thirsty
                                              ? const Color(0xFF9A3412)
                                              : kInk.withValues(alpha: 0.72),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                          shadows: [
                                            Shadow(
                                              color: Colors.white
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 292,
                                  width: double.infinity,
                                  child: _GardenPlantDock(
                                    plant: p,
                                    logic: _logic,
                                    pulse: _tapFeedbackIndex == idx,
                                    showWaterSpray: _sprayPlantIndex == idx,
                                    waterSprayKey: ValueKey<int>(_spraySeq),
                                    reduceMotion: _reduceMotion,
                                    spraySlotHeight: 96,
                                    onTap: () => _waterPlantAt(idx),
                                  ),
                                ),
                                if (thirsty) ...[
                                  const SizedBox(height: 12),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _waterPlantAt(idx),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Ink(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF0D9488),
                                              Color(0xFF0F766E),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x5A0F766E),
                                              blurRadius: 14,
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Icon(
                                                Icons.water_drop_rounded,
                                                color: Color(0xFFF0FDFA),
                                                size: 22,
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Water with sprayer',
                                                style: TextStyle(
                                                  color: Color(0xFFF0FDFA),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else if (!p.isDead)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 8, sigmaY: 8),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 11,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            color: Colors.white
                                                .withValues(alpha: 0.18),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            'This plant is stable — tap outside to return to the field.',
                                            textAlign: TextAlign.center,
                                            style: ink(12.5, FontWeight.w600,
                                                h: 1.35),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPlantChip extends StatelessWidget {
  const _FieldPlantChip({
    required this.plant,
    required this.logic,
    required this.reduceMotion,
    required this.onTap,
  });

  final WateringPlant plant;
  final WateringFlowersLogic logic;
  final bool reduceMotion;
  final VoidCallback onTap;

  static const List<double> _kGrayMatrix = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final String mood = logic.plantMoodEmoji(plant, _dummyCfg);

    Widget plantLottie = Lottie.asset(
      plant.lottieAsset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      repeat: !reduceMotion && !plant.isDead,
      animate: !plant.isDead,
    );

    if (plant.isDead) {
      plantLottie = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGrayMatrix),
        child: Opacity(opacity: 0.72, child: plantLottie),
      );
    } else {
      plantLottie = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Color.lerp(Colors.white, plant.accentColor, 0.2)!,
          BlendMode.modulate,
        ),
        child: plantLottie,
      );
      if (plant.awaitingWater) {
        plantLottie = ColorFiltered(
          colorFilter: ColorFilter.mode(
            const Color(0xFFFF9800).withValues(alpha: 0.28),
            BlendMode.srcATop,
          ),
          child: plantLottie,
        );
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: plant.isDead
                  ? Colors.grey.shade600
                  : plant.awaitingWater
                      ? const Color(0xFFFFF59D)
                      : Colors.white24,
              width: plant.awaitingWater ? 2.0 : 1,
            ),
            boxShadow: plant.awaitingWater
                ? [
                    BoxShadow(
                      color:
                          const Color(0xFFFFF59D).withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(mood, style: const TextStyle(fontSize: 11, height: 1)),
              Expanded(
                child: Transform.scale(
                  scale: 0.52,
                  alignment: Alignment.bottomCenter,
                  child: plantLottie,
                ),
              ),
              if (plant.awaitingWater && !plant.isDead)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: plant.patience.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: Colors.white30,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(
                        const Color(0xFFE53935),
                        const Color(0xFF43A047),
                        plant.patience,
                      )!,
                    ),
                  ),
                )
              else if (!plant.isDead)
                Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GardenPlantDock extends StatelessWidget {
  const _GardenPlantDock({
    required this.plant,
    required this.logic,
    required this.pulse,
    required this.showWaterSpray,
    required this.waterSprayKey,
    required this.reduceMotion,
    this.spraySlotHeight = 50,
    required this.onTap,
  });

  final WateringPlant plant;
  final WateringFlowersLogic logic;
  final bool pulse;
  final bool showWaterSpray;
  final Key waterSprayKey;
  final bool reduceMotion;
  final double spraySlotHeight;
  final VoidCallback onTap;

  static const List<double> _kGrayMatrix = <double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final String mood = logic.plantMoodEmoji(plant, _dummyCfg);

    Widget plantLottie = Lottie.asset(
      plant.lottieAsset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      repeat: !reduceMotion && !plant.isDead,
      animate: !plant.isDead,
    );

    if (plant.isDead) {
      plantLottie = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kGrayMatrix),
        child: Opacity(opacity: 0.72, child: plantLottie),
      );
    } else {
      plantLottie = ColorFiltered(
        colorFilter: ColorFilter.mode(
          Color.lerp(Colors.white, plant.accentColor, 0.2)!,
          BlendMode.modulate,
        ),
        child: plantLottie,
      );
      if (plant.awaitingWater) {
        plantLottie = ColorFiltered(
          colorFilter: ColorFilter.mode(
            const Color(0xFFFF9800).withValues(alpha: 0.28),
            BlendMode.srcATop,
          ),
          child: plantLottie,
        );
      }
    }

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: plant.isDead
                    ? Colors.grey.shade600
                    : plant.awaitingWater
                        ? const Color(0xFFFFF59D)
                        : Colors.white30,
                width: plant.awaitingWater ? 2.4 : 1.1,
              ),
              boxShadow: plant.awaitingWater
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFFF59D).withValues(alpha: 0.38),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(mood, style: const TextStyle(fontSize: 16, height: 1)),
                SizedBox(
                  height: spraySlotHeight,
                  child: showWaterSpray
                      ? Lottie.asset(
                          WateringGardenLottieAssets.waterSpray,
                          key: waterSprayKey,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          repeat: false,
                          animate: true,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: AnimatedScale(
                    scale: pulse ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    child: plantLottie,
                  ),
                ),
                if (plant.awaitingWater && !plant.isDead) ...[
                  const SizedBox(height: 2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: plant.patience.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: Colors.white38,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(
                          const Color(0xFFE53935),
                          const Color(0xFF43A047),
                          plant.patience,
                        )!,
                      ),
                    ),
                  ),
                Text(
                  'Patience',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ] else if (!plant.isDead)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Stable',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
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

/// Placeholder for [plantMoodEmoji] in mini dock (unused tier fields).
const WateringLevelConfig _dummyCfg = WateringLevelConfig(
  id: 0,
  levelTitle: '',
  tier: '',
  seconds: 60,
  waterMax: 100,
  plantCount: 8,
  waterCostPerTap: 5,
  patienceDrainPerSecond: 0.08,
  demandIntervalMinSec: 3,
  demandIntervalMaxSec: 7,
  pointsPerWater: 10,
  pointsLostPerDeadPlant: 20,
);
