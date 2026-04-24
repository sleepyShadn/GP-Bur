import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

class GameAudioService {
  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'game_bgm');
  /// Loops [game_start.wav] while the pre-game card is visible (dedicated player).
  final AudioPlayer _preGamePlayer = AudioPlayer(playerId: 'game_pregame');
  final List<AudioPlayer> _sfxPlayers = List.generate(
    3,
    (i) => AudioPlayer(playerId: 'game_sfx_$i'),
  );
  int _sfxRotor = 0;

  static final AudioContext _mixingContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  Future<void> init() async {
    await AudioPlayer.global.setAudioContext(_mixingContext);
    await Future.wait([
      _bgmPlayer.setAudioContext(_mixingContext),
      _preGamePlayer.setAudioContext(_mixingContext),
      ..._sfxPlayers.map((p) => p.setAudioContext(_mixingContext)),
    ]);
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _preGamePlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await Future.wait(
      _sfxPlayers.map((p) => p.setPlayerMode(PlayerMode.mediaPlayer)),
    );
  }

  Future<void> startPreGameLoop() async {
    try {
      await _preGamePlayer.setReleaseMode(ReleaseMode.loop);
      await _safePlay(_preGamePlayer, 'game_start.wav', volume: 0.85);
    } catch (_) {}
  }

  Future<void> stopPreGameLoop() async {
    try {
      await _preGamePlayer.stop();
    } catch (_) {}
  }

  Future<void> playBgm() async {
    await _safePlay(_bgmPlayer, 'bg_game_loop.mp3', volume: 0.35);
  }

  Future<void> pauseBgm() async {
    try {
      await _bgmPlayer.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    try {
      await _bgmPlayer.resume();
    } catch (_) {}
  }

  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  Future<void> playAppleCatch() async => _playSfx('apple_catch.wav');
  Future<void> playRottenHit() async => _playSfx('apple_rotten.wav');
  Future<void> playBonusCatch() async => _playSfx('bonus_pickup.wav');
  Future<void> playLevelUp() async => _playSfx('level_up.wav');
  Future<void> playPause() async => _playSfx('pause.wav');
  Future<void> playResume() async => _playSfx('resume.wav');
  Future<void> playGameOver() async => _playSfx('game_over.wav');
  Future<void> playButtonTap() async => _playSfx('button_tap.wav');

  Future<void> dispose() async {
    await _bgmPlayer.dispose();
    await _preGamePlayer.dispose();
    await Future.wait(_sfxPlayers.map((p) => p.dispose()));
  }

  Future<void> _playSfx(String fileName) async {
    final player = _sfxPlayers[_sfxRotor];
    _sfxRotor = (_sfxRotor + 1) % _sfxPlayers.length;
    await _safePlay(player, fileName, volume: 0.9);
  }

  Future<void> _safePlay(
    AudioPlayer player,
    String fileName, {
    required double volume,
  }) async {
    try {
      await player.stop();
      await player.play(
        AssetSource('sounds/$fileName'),
        volume: volume,
      );
    } catch (_) {}
  }
}
