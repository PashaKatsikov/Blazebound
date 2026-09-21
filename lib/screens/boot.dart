import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art.dart';
import '../look.dart';
import 'menu.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  double _p = 0;
  String _line = 'Warming the rings...';

  static const _lines = [
    'Warming the rings...',
    'Minting fire coins...',
    'Lighting the tent...',
    'Calling the Joker...',
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await Art.I.load((v) {
      if (!mounted) return;
      setState(() {
        _p = v;
        _line = _lines[(v * (_lines.length - 0.01)).floor().clamp(0, _lines.length - 1)];
      });
    });
    await Future<void>.delayed(const Duration(milliseconds: 280));
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, _, _) => const MenuScreen(),
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tall = MediaQuery.of(context).orientation == Orientation.portrait;
    return Scaffold(
      backgroundColor: Dye.abyss,
      body: Stack(
        fit: StackFit.expand,
        children: [
        Positioned.fill(child: Image.asset(tall ? Paths.loadV : Paths.loadH, fit: BoxFit.cover)),
          const SparkleField(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 0, 28, tall ? 48 : 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_line, style: bodyStyle(14, color: Dye.goldHi)),
                  const SizedBox(height: 10),
                  GoldFrame(
                    radius: 10,
                    pad: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _p.clamp(0.04, 1),
                        minHeight: 10,
                        backgroundColor: const Color(0xFF2A0A10),
                        color: Dye.ember,
                      ),
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
}
