import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'garden_seed_farm_screen.dart';

class GardenGameLoadingScreen extends StatefulWidget {
  const GardenGameLoadingScreen({super.key, required this.initialSeason});

  final String initialSeason;

  @override
  State<GardenGameLoadingScreen> createState() => _GardenGameLoadingScreenState();
}

class _GardenGameLoadingScreenState extends State<GardenGameLoadingScreen> {
  Timer? _progressTimer;
  double _progress = 0.0;
  bool _canStart = false;
  bool _openingGame = false;

  @override
  void initState() {
    super.initState();
    _setLandscape();
    _startFakeLoading();
  }

  Future<void> _setLandscape() async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _startFakeLoading() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (Timer t) {
      if (!mounted) return;
      setState(() {
        _progress = (_progress + 0.02).clamp(0.0, 1.0);
        if (_progress >= 1.0) {
          _canStart = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _startGame() async {
    _openingGame = true;
    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            GardenSeedFarmScreen(initialSeason: widget.initialSeason),
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    if (!_openingGame) {
      SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double pct = (_progress * 100).roundToDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF0C1E1A),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: Lottie.asset(
                'assets/animations/sunrise.json',
                fit: BoxFit.fill,
                repeat: true,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.46),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text(
                        'Preparing Your Garden Adventure',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _canStart
                            ? 'Everything is ready. Tap Start Game to begin.'
                            : 'Loading crops, seasons, and rewards...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 13,
                          value: _progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _canStart ? _startGame : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Start Game',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF66BB6A),
                            disabledBackgroundColor: const Color(0xFF66BB6A).withValues(alpha: 0.45),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
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
}
