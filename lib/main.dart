import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'look.dart';
import 'profile.dart';
import 'screens/boot.dart';
import 'sfx.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final vault = Profile();
  await vault.boot();
  Sfx.I.live = vault.sfxOn;
  Sfx.I.shake = vault.rumble;
  runApp(Vault(profile: vault, child: const BlazeApp()));
}

class BlazeApp extends StatelessWidget {
  const BlazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blazebound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Dye.abyss,
        colorScheme: const ColorScheme.dark(
          primary: Dye.gold,
          secondary: Dye.ember,
          surface: Dye.panelSolid,
        ),
        snackBarTheme: const SnackBarThemeData(backgroundColor: Dye.wine),
      ),
      home: const BootScreen(),
    );
  }
}
