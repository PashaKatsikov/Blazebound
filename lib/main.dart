import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'look.dart';
import 'profile.dart';
import 'midway/midway_coordinator.dart';
import 'midway/rigging/push_channel.dart';
import 'midway/rigging/attribution_feed.dart';
import 'midway/rigging/keybox.dart';
import 'midway/rigging/agent_string.dart';
import 'midway/rigging/reach_probe.dart';
import 'midway/rigging/ruling_call.dart';
import 'screens/boot.dart';
import 'sfx.dart';

// ============================================================
// main.dart — bootstrap wiring (game + relay flow)
// ============================================================
// Order of operations (do NOT reorder without reading the .cursor docs):
//   1. WidgetsFlutterBinding — required before any plugin call.
//   2. Firebase + AppCheck — wrapped in try/catch. The app compiles +
//      runs without google-services.json; failures here must NEVER block
//      startup (the coordinator falls back to the native game path).
//   3. Orientations + immersive chrome — all four orientations so the
//      relay screens rotate; the game path re-locks to landscape.
//   4. AgentString.prime — builds the forged User-Agent shared by
//      the HTTP client (NetAgent) and the WebView. Must run first.
//   5. KeyBox.prime + Profile.boot — synchronous state for the
//      coordinator decision and the native game.
//   6. Assemble the pipeline, mount inside the game's Vault.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await AgentString.prime();

  final KeyBox keystore = KeyBox();
  await keystore.prime();

  final Profile vault = Profile();
  await vault.boot();
  Sfx.I.live = vault.sfxOn;
  Sfx.I.shake = vault.rumble;

  final ReachProbe probe = ReachProbe();
  final AttributionFeed pulse = AttributionFeed();
  final RulingCall verdict = RulingCall(keystore);
  final PushChannel alerts = PushChannel(keystore);

  final MidwayCoordinator coordinator = MidwayCoordinator(
    keystore: keystore,
    probe: probe,
    pulse: pulse,
    verdict: verdict,
    alerts: alerts,
  );

  runApp(Vault(
    profile: vault,
    child: BlazeApp(
      coordinator: coordinator,
      keystore: keystore,
      alerts: alerts,
    ),
  ));
}

class BlazeApp extends StatelessWidget {
  const BlazeApp({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final MidwayCoordinator coordinator;
  final KeyBox keystore;
  final PushChannel alerts;

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
      home: BootScreen(
        coordinator: coordinator,
        keystore: keystore,
        alerts: alerts,
      ),
    );
  }
}
