import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class GardenAudioService {
  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'garden_bgm');
  bool _gardenBgmActive = false;

  final AudioPlayer _harvestStartPlayer =
      AudioPlayer(playerId: 'harvest_game_start');

  final AudioPlayer _introRoundStartPlayer =
      AudioPlayer(playerId: 'garden_intro_round');

  final List<AudioPlayer> _sfxPlayers = List.generate(
    5,
    (i) => AudioPlayer(playerId: 'garden_sfx_$i'),
  );
  int _sfxRotor = 0;
  bool _disposed = false;
  bool _disposing = false;

  static final AudioContext _mixingContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  Future<void> init() async {
    if (_disposed || _disposing) return;
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
    if (_disposed || _disposing) return;
    _disposing = true;
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
    _disposed = true;
    _disposing = false;
  }

  Future<void> haltAllPlayback() async {
    if (_disposed) return;
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

  Future<void> playExitGameOver() async {
    if (_disposed || _disposing) return;
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

  Future<void> startGardenIntroRoundStartLoop() async {
    if (_disposed || _disposing) return;
    try {
      await _bgmPlayer.stop();
      _gardenBgmActive = false;
      await _harvestStartPlayer.stop();
      await _introRoundStartPlayer.stop();
      await _introRoundStartPlayer.setReleaseMode(ReleaseMode.loop);
      await _introRoundStartPlayer.setVolume(0.52);
      for (final String name in <String>[
        'harvest_game_start.wav',
        'game_start.wav',
      ]) {
        try {
          await _introRoundStartPlayer.play(
            AssetSource('sounds/$name'),
          );
          break;
        } catch (e) {
          debugPrint('GardenAudioService intro loop missing or failed: sounds/$name — $e');
        }
      }
    } catch (_) {}
  }

  Future<void> stopGardenIntroRoundStartCue() async {
    if (_disposed || _disposing) return;
    try {
      await _introRoundStartPlayer.stop();
    } catch (_) {}
  }

  Future<void> startGardenCareBgm() async {
    if (_disposed || _disposing) return;
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
    if (_disposed || _disposing) return;
    if (!_gardenBgmActive) return;
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeGardenCareBgm() async {
    if (_disposed || _disposing) return;
    if (!_gardenBgmActive) return;
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  Future<void> stopGardenCareBgm() async {
    if (_disposed || _disposing) return;
    _gardenBgmActive = false;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> playHarvestGameStartThenBgm() async {
    if (_disposed || _disposing) return;
    await stopGardenIntroRoundStartCue();
    await stopGardenCareBgm();
    try {
      await _harvestStartPlayer.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 80));

    for (final String name in <String>['harvest_game_start.wav', 'game_start.wav']) {
      if (_disposed || _disposing) return;
      try {
        await _harvestStartPlayer.setReleaseMode(ReleaseMode.release);
        await _harvestStartPlayer.setVolume(0.88);
        await _harvestStartPlayer.play(AssetSource('sounds/$name'));
        await _harvestStartPlayer.onPlayerComplete.first.timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            debugPrint('GardenAudioService: sounds/$name — onPlayerComplete timeout');
          },
        );
        break;
      } catch (e) {
        debugPrint('GardenAudioService harvest start sting missing or failed: sounds/$name — $e');
        try {
          await _harvestStartPlayer.stop();
        } catch (_) {}
      }
    }

    if (_disposed || _disposing) return;
    await startHarvestRunBgm();
  }

  Future<void> startHarvestRunBgm() async {
    if (_disposed || _disposing) return;
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
      return;
    }
    debugPrint(
      'GardenAudioService: no harvest BGM asset found '
      '(sounds/harvest_run_bgm.mp3|.wav, then bg_game_loop.mp3, garden_care_bgm.mp3).',
    );
  }

  Future<void> ensureHarvestRunBgm() async {
    if (_disposed || _disposing) return;
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
    if (_disposed || _disposing) return;
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
