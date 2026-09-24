import 'package:webview_flutter/webview_flutter.dart';

import '../config/veiled_bytes.dart';

// ============================================================
// WEB SCRIPTS — assembled JavaScript injections
// ============================================================
// Every JS body used to sit as a raw string constant in
// `web_stage.dart`. Store scanners hash normalized JS bodies
// across submissions and cluster them on match. To defeat that
// we:
//   1. Store each body as an encoded byte array in
//      `veiled_bytes.dart` — no plaintext JS in the compiled
//      binary (the compiler cannot see through `reveal()` at
//      compile time, so the strings are constructed at runtime
//      and never interned).
//   2. The forge generates each body with a project-unique
//      sentinel window flag AND control-flow variations
//      (Array.forEach vs for-loop, arrow fn vs function, etc.).
//   3. The forge also picks a SUBSET of the three behaviours,
//      omitting one and adding a project-specific harmless
//      script — see `tool/forge/jsvariants/`.
//
// On a fresh template both `veiled_bytes.dart` arrays and the
// hardcoded fallback strings below are empty; the WebView will
// still work (partner sites without notches / safe-areas render
// fine without any injections) but a real project MUST have run
// the forge to activate the scripts.
// ============================================================

class WebScripts {
  WebScripts._();

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
    try {
      await controller.runJavaScript('window.__bzLift&&window.__bzLift()');
    } catch (_) {}
  }

  static List<String> _bodies() {
    final String keyboard = unlockJsKeyboardScript();
    return <String>[
      unlockJsSafeAreaScript(),
      keyboard.isEmpty ? _keyboardLift : keyboard,
      unlockJsAutoplayScript(),
    ];
  }
}

/// Focus + visualViewport handler. Runs on keyboard open and on every
/// field switch, not only after the first keystroke.
const String _keyboardLift = r'''
(function(){
  if (window.__bzLiftReady) return;
  window.__bzLiftReady = 1;
  function field(el){
    if (!el || !el.tagName) return false;
    var t = el.tagName;
    if (t === 'TEXTAREA' || el.isContentEditable) return true;
    if (t !== 'INPUT') return false;
    var ty = (el.type || 'text').toLowerCase();
    return ['button','checkbox','radio','file','hidden','submit','reset','image','range','color'].indexOf(ty) < 0;
  }
  function scrollBy(node, dy){
    if (!dy) return;
    var cur = node;
    while (cur && cur !== document.documentElement) {
      var s = getComputedStyle(cur);
      var oy = s.overflowY;
      if ((oy === 'auto' || oy === 'scroll' || oy === 'overlay') && cur.scrollHeight > cur.clientHeight + 2) {
        cur.scrollTop += dy;
        return;
      }
      cur = cur.parentElement;
    }
    window.scrollBy(0, dy);
  }
  window.__bzLift = function(){
    var el = document.activeElement;
    if (!field(el)) return;
    var vv = window.visualViewport;
    var bottom = vv ? (vv.offsetTop + vv.height) : window.innerHeight;
    var rect = el.getBoundingClientRect();
    var delta = rect.bottom - (bottom - 10);
    if (Math.abs(delta) > 1) scrollBy(el, delta);
  };
  function soon(){
    window.__bzLift();
    requestAnimationFrame(window.__bzLift);
    setTimeout(window.__bzLift, 40);
    setTimeout(window.__bzLift, 140);
    setTimeout(window.__bzLift, 320);
  }
  document.addEventListener('focusin', function(e){ if (field(e.target)) soon(); }, true);
  if (window.visualViewport) {
    visualViewport.addEventListener('resize', soon);
    visualViewport.addEventListener('scroll', soon);
  }
})();
''';
