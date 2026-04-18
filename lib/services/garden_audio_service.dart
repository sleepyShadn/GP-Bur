import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// أصوات لعبة «رعاية الحديقة»: [موسيقى خلفية منفصلة] + [مؤثرات SFX على لاعبين آخرين] حتى لا يقطع المؤثر الموسيقى.
///
/// أسماء الملفات المتوقعة تحت `assets/sounds/` (انظر أيضاً [assets/sounds/README.txt]):
/// - garden_tool_grab.wav (حلقة خلفية بعد START؛ احتياطي: bg_game_loop.mp3 ثم garden_care_bgm.mp3)
/// - garden_water_spray.wav, garden_fertilizer_pour.wav, garden_weed_waste.wav
/// - garden_level_complete.wav, garden_game_over.wav, garden_timer_warning.wav, garden_round_start.wav
/// - garden_bonus_spawn.wav, garden_bonus_pickup.wav, garden_plant_focus_open.wav
/// - button_tap.wav, level_up.wav (مشتركان مع لعبة التفاحات)
/// - garden_round_start.wav — لاعب منفصل: حلقة بطاقة START ثم يُوقف عند الضغط على START
class GardenAudioService {
  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'garden_bgm');
  bool _gardenBgmActive = false;

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
    await _introRoundStartPlayer.setAudioContext(_mixingContext);
    await _introRoundStartPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await Future.wait(_sfxPlayers.map((p) async {
      await p.setAudioContext(_mixingContext);
      await p.setPlayerMode(PlayerMode.mediaPlayer);
    }));
  }

  Future<void> dispose() async {
    _gardenBgmActive = false;
    try {
      await _introRoundStartPlayer.stop();
    } catch (_) {}
    await _introRoundStartPlayer.dispose();
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
    await _bgmPlayer.dispose();
    await Future.wait(_sfxPlayers.map((p) => p.dispose()));
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
