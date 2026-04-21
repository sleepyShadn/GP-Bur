import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// أصوات لعبة «رعاية الحديقة»: [موسيقى خلفية منفصلة] + [مؤثرات SFX على لاعبين آخرين] حتى لا يقطع المؤثر الموسيقى.
///
/// لعبة الحصاد (Harvest Run): [harvest_game_start] لاعب منفصل → ثم [harvest_run_bgm] على نفس لاعب الـ BGM؛
/// المؤثرات الأخرى على لاعبات SFX دون قطع الخلفية.
///
/// أسماء الملفات المتوقعة تحت `assets/sounds/` (انظر أيضاً [assets/sounds/README.txt]):
/// - harvest_game_start.wav — نقرة بداية لعبة الحصاد (مرة واحدة ثم الخلفية)
/// - harvest_run_bgm.mp3 أو harvest_run_bgm.wav — موسيقى حلقة أثناء جولة الحصاد
/// - garden_tool_grab.wav (حلقة خلفية بعد START؛ احتياطي: bg_game_loop.mp3 ثم garden_care_bgm.mp3)
/// - garden_water_spray.wav, garden_fertilizer_pour.wav, garden_weed_waste.wav
/// - garden_level_complete.wav, garden_game_over.wav, garden_timer_warning.wav, garden_round_start.wav
/// - garden_bonus_spawn.wav, garden_bonus_pickup.wav, garden_plant_focus_open.wav
/// - button_tap.wav, level_up.wav (مشتركان مع لعبة التفاحات)
/// - garden_round_start.wav — لاعب منفصل: حلقة بطاقة START ثم يُوقف عند الضغط على START
class GardenAudioService {
  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'garden_bgm');
  bool _gardenBgmActive = false;

  /// نقرة بداية لعبة الحصاد (مرة واحدة) — لاعب منفصل عن الـ BGM وعن الـ SFX.
  final AudioPlayer _harvestStartPlayer =
      AudioPlayer(playerId: 'harvest_game_start');

  /// حلقة انتظار شاشة البداية — لا يستخدم لاعب الـ SFX حتى لا يتوقف مع مؤثر آخر.
  final AudioPlayer _introRoundStartPlayer =
      AudioPlayer(playerId: 'garden_intro_round');

  final List<AudioPlayer> _sfxPlayers = List.generate(
    5,
    (i) => AudioPlayer(playerId: 'garden_sfx_$i'),
  );
  int _sfxRotor = 0;

  static final AudioContext _mixingContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  Future<void> init() async {
    await AudioPlayer.global.setAudioContext(_mixingContext);
    await _bgmPlayer.setAudioContext(_mixingContext);
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _harvestStartPlayer.setAudioContext(_mixingContext);
    await _harvestStartPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _harvestStartPlayer.setReleaseMode(ReleaseMode.release);
    await _introRoundStartPlayer.setAudioContext(_mixingContext);
    await _introRoundStartPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await Future.wait(_sfxPlayers.map((p) async {
      await p.setAudioContext(_mixingContext);
      await p.setPlayerMode(PlayerMode.mediaPlayer);
    }));
  }

  Future<void> dispose() async {
    await haltAllPlayback();
    try {
      await _harvestStartPlayer.dispose();
    } catch (_) {}
    try {
      await _introRoundStartPlayer.dispose();
    } catch (_) {}
    try {
      await _bgmPlayer.dispose();
    } catch (_) {}
    await Future.wait(_sfxPlayers.map((p) => p.dispose()));
  }

  /// إيقاف كل اللاعبين (خلفية، بداية الحصاد، intro، SFX) — آمن للاستدعاء قبل الخروج من الشاشة.
  Future<void> haltAllPlayback() async {
    _gardenBgmActive = false;
    Future<void> safe(Future<void> f) async {
      try {
        await f;
      } catch (_) {}
    }

    await Future.wait(<Future<void>>[
      safe(_harvestStartPlayer.stop()),
      safe(_introRoundStartPlayer.stop()),
      safe(_bgmPlayer.stop()),
      ..._sfxPlayers.map((AudioPlayer p) => safe(p.stop())),
    ]);
  }

  /// صوت خروج من اللعبة (لعبة التفاح أولاً ثم حديقة).
  Future<void> playExitGameOver() async {
    for (final String name in <String>['game_over.wav', 'garden_game_over.wav']) {
      try {
        final AudioPlayer player = _sfxPlayers[_sfxRotor];
        _sfxRotor = (_sfxRotor + 1) % _sfxPlayers.length;
        await player.stop();
        await player.play(
          AssetSource('sounds/$name'),
          volume: 0.74,
        );
        return;
      } catch (_) {}
    }
  }

  /// يُشغَّل أثناء بطاقة «START GAME» فقط (حلقة [garden_round_start]).
  Future<void> startGardenIntroRoundStartLoop() async {
    try {
      await _introRoundStartPlayer.stop();
      await _introRoundStartPlayer.setReleaseMode(ReleaseMode.loop);
      await _introRoundStartPlayer.setVolume(0.52);
      await _introRoundStartPlayer.play(
        AssetSource('sounds/garden_round_start.wav'),
      );
    } catch (_) {}
  }

  Future<void> stopGardenIntroRoundStartCue() async {
    try {
      await _introRoundStartPlayer.stop();
    } catch (_) {}
  }

  /// موسيقى/حلقة خلفية أثناء اللعب؛ لا تُوقفها مؤثرات [playWaterSpray] وغيرها.
  Future<void> startGardenCareBgm() async {
    if (_gardenBgmActive) return;
    Future<bool> tryPlay(String asset, double volume) async {
      try {
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(volume);
        await _bgmPlayer.play(AssetSource(asset));
        return true;
      } catch (_) {
        return false;
      }
    }

    if (await tryPlay('sounds/garden_tool_grab.wav', 0.34)) {
      _gardenBgmActive = true;
      return;
    }
    if (await tryPlay('sounds/bg_game_loop.mp3', 0.30)) {
      _gardenBgmActive = true;
      return;
    }
    if (await tryPlay('sounds/garden_care_bgm.mp3', 0.30)) {
      _gardenBgmActive = true;
    }
  }

  Future<void> pauseGardenCareBgm() async {
    if (!_gardenBgmActive) return;
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeGardenCareBgm() async {
    if (!_gardenBgmActive) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  Future<void> stopGardenCareBgm() async {
    _gardenBgmActive = false;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  /// يُستدعى من زر START GAME في Harvest Run: يوقف أي BGM، يشغّل [harvest_game_start] حتى النهاية، ثم حلقة [harvest_run_bgm].
  Future<void> playHarvestGameStartThenBgm() async {
    await stopGardenCareBgm();
    try {
      await _harvestStartPlayer.stop();
      await _harvestStartPlayer.setReleaseMode(ReleaseMode.release);
      await _harvestStartPlayer.setVolume(0.82);
      for (final String name in <String>[
        'harvest_game_start.wav',
        'game_start.wav',
      ]) {
        try {
          final Future<void> done = _harvestStartPlayer.onPlayerComplete.first;
          await _harvestStartPlayer.play(AssetSource('sounds/$name'));
          await done.timeout(const Duration(seconds: 24), onTimeout: () {});
          break;
        } catch (_) {
          try {
            await _harvestStartPlayer.stop();
          } catch (_) {}
        }
      }
    } catch (_) {}
    await startHarvestRunBgm();
  }

  /// موسيقى حلقة أثناء جولة الحصاد؛ لا تُوقفها مؤثرات الـ SFX.
  Future<void> startHarvestRunBgm() async {
    if (_gardenBgmActive) return;
    Future<bool> tryPlay(String asset, double volume) async {
      try {
        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(volume);
        await _bgmPlayer.play(AssetSource(asset));
        return true;
      } catch (_) {
        return false;
      }
    }

    if (await tryPlay('sounds/harvest_run_bgm.mp3', 0.36)) {
      _gardenBgmActive = true;
      return;
    }
    if (await tryPlay('sounds/harvest_run_bgm.wav', 0.36)) {
      _gardenBgmActive = true;
      return;
    }
    if (await tryPlay('sounds/bg_game_loop.mp3', 0.30)) {
      _gardenBgmActive = true;
      return;
    }
    if (await tryPlay('sounds/garden_care_bgm.mp3', 0.30)) {
      _gardenBgmActive = true;
    }
  }

  /// إن لم تكن الخلفية شغّالة (بعد نهاية جولة أو أول تشغيل)، ابدأ حلقة الحصاد.
  Future<void> ensureHarvestRunBgm() async {
    await startHarvestRunBgm();
  }

  Future<void> playToolGrab() async => _playSfx('garden_tool_grab.wav', volume: 0.75);

  Future<void> playWaterSpray() async => _playSfx('garden_water_spray.wav', volume: 0.55);

  Future<void> playFertilizerPour() async => _playSfx('garden_fertilizer_pour.wav', volume: 0.6);

  Future<void> playWeedWaste() async => _playSfx('garden_weed_waste.wav', volume: 0.65);

  Future<void> playLevelComplete() async => _playSfx('garden_level_complete.wav', volume: 0.82);

  Future<void> playGameOver() async => _playSfx('garden_game_over.wav', volume: 0.72);

  Future<void> playTimerWarning() async => _playSfx('garden_timer_warning.wav', volume: 0.68);

  Future<void> playRoundStart() async => _playSfx('garden_round_start.wav', volume: 0.62);

  /// نفس ملفات لعبة التفاح إن وُجدت — للإيقاف المؤقت / الاستئناف.
  Future<void> playPause() async => _playSfx('pause.wav', volume: 0.75);

  Future<void> playResume() async => _playSfx('resume.wav', volume: 0.75);

  Future<void> playButtonTap() async =>
      _playSfx('button_tap.wav', volume: 0.72);

  Future<void> playBonusWaterSpawn() async =>
      _playSfx('garden_bonus_spawn.wav', volume: 0.58);

  Future<void> playBonusWaterPickup() async =>
      _playSfx('garden_bonus_pickup.wav', volume: 0.78);

  Future<void> playPlantFocusOpen() async =>
      _playSfx('garden_plant_focus_open.wav', volume: 0.62);

  Future<void> playLevelUp() async => _playSfx('level_up.wav', volume: 0.78);

  Future<void> _playSfx(String fileName, {required double volume}) async {
    final player = _sfxPlayers[_sfxRotor];
    _sfxRotor = (_sfxRotor + 1) % _sfxPlayers.length;
    try {
      await player.stop();
      await player.play(
        AssetSource('sounds/$fileName'),
        volume: volume,
      );
    } catch (_) {}
  }
}
