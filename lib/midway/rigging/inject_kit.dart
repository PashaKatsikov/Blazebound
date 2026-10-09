import 'package:webview_flutter/webview_flutter.dart';

import '../brief/masked_bytes.dart';
import '../vault/native_vault.dart';
import '../vault/vault_blobs.dart';

// ============================================================
// INJECT KIT — assembled JavaScript injections
// ============================================================
// Every JS body used to sit as a raw string constant. Store scanners hash
// normalized JS bodies across submissions and cluster them on match. To
// defeat that, no JS body is a Dart literal anymore:
//   • The keyboard-seating script and the two inline bridge snippets live
//     XOR-encoded in the native vault (android/rust/.../vault.rs) and are
//     pulled here per call via `NativeVault.get`, re-encrypted on the wire.
//     So a `strings` dump of the APK/.so and a Dart-side decode both miss
//     them — the script text exists only for the single runJavaScript call.
//   • The optional safe-area / autoplay bodies stay forge-sourced through
//     `masked_bytes.dart` (empty on a raw checkout).
//
// Off Android the vault returns '' and the WebView simply skips the
// enhancers (partner sites without notches / custom keyboards still render).
// ============================================================

class InjectKit {
  InjectKit._();

  /// Install the ORDERED sequence of enhancers on the given
  /// controller. Every enhancer is idempotent via its own sentinel
  /// window flag — safe to call on every `onPageFinished`.
  static Future<void> installAll(WebViewController controller) async {
    for (final String body in _bodies()) {
      if (body.isEmpty) continue;
      await controller.runJavaScript(body);
    }
    await liftFocusedField(controller);
  }

  /// Pull the focused field so it sits just above the keyboard.
  /// Safe to call on focus, on IME inset changes, and on field switches.
  static Future<void> liftFocusedField(WebViewController controller) async {
    final String js = _vault(kVaultJsPerchCall);
    if (js.isEmpty) return;
    try {
      await controller.runJavaScript(js);
    } catch (_) {}
  }

  /// Push the current keyboard-occupancy fraction (0..1) into the page.
  /// The bundled JS then seats the focused field just above the keyboard.
  /// The WebView is NOT resized by Flutter — the page owns every pixel and
  /// only the field (or its nearest fixed-position ancestor) is translated.
  static Future<void> setKeyboardShare(
    WebViewController controller,
    double share,
  ) async {
    final double clamped = share.isNaN ? 0 : share.clamp(0.0, 1.0);
    final String tpl = _vault(kVaultJsKbshareTpl);
    if (tpl.isEmpty) return;
    final String js = tpl.replaceAll('%SHARE%', clamped.toStringAsFixed(5));
    try {
      await controller.runJavaScript(js);
    } catch (_) {}
  }

  /// JS body from the native vault (Android); '' off Android.
  static String _vault(int key) =>
      NativeVault.isSupported ? NativeVault.get(key) : '';

  static List<String> _bodies() {
    return <String>[
      // safe-area + autoplay stay forge-sourced (empty on a raw checkout).
      unlockJsSafeAreaScript(),
      _vault(kVaultJsKeyboard),
      unlockJsAutoplayScript(),
    ];
  }
}
