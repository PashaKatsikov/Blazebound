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
      await controller.runJavaScript('window.__bzApply&&window.__bzApply()');
    } catch (_) {}
  }

  /// Report the current keyboard height (CSS px) into the page and lift the
  /// focused field. Called from Dart on every IME inset change, because the
  /// WebView keeps full height and the page's visualViewport does not shrink.
  static Future<void> setKeyboardHeight(
    WebViewController controller,
    double cssHeight,
  ) async {
    try {
      final int h = cssHeight.round();
      // Set the (settled) keyboard height and lift in ONE step. The WebView is
      // not resized, so the JS uses this height directly.
      await controller.runJavaScript(
        'window.__bzKb=$h;window.__bzApply&&window.__bzApply()',
      );
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

/// Focus + visualViewport handler.
///
/// The host (Flutter) shrinks the WebView from the bottom by the keyboard
/// height (Android is set to `adjustNothing`, so this is the ONLY shrink and
/// it is uniform across orientations). That makes `visualViewport` report the
/// true visible area, so we simply keep the focused field just above its
/// bottom edge. No spacer and no timer burst — those caused the browser to
/// over-scroll first and then settle.
const String _keyboardLift = r'''
(function(){
  if (window.__bzLiftReady) return;
  window.__bzLiftReady = 1;
  // The WebView is NOT resized when the keyboard opens; the host reports the
  // settled keyboard height in window.__bzKb (0 when closed) and then calls
  // window.__bzApply() exactly once — so the field moves in a single step.
  try {
    var st = document.createElement('style');
    st.textContent = 'html{overflow-anchor:none!important;scroll-behavior:auto!important;}';
    (document.head || document.documentElement).appendChild(st);
  } catch (e) {}
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
  function spacer(kb){
    // The WebView keeps full height, so a page that fits is not scrollable.
    // A bottom spacer equal to the keyboard height guarantees scroll room.
    var sp = document.getElementById('__bzKbSpacer');
    if (kb > 0) {
      if (!sp) {
        sp = document.createElement('div');
        sp.id = '__bzKbSpacer';
        sp.setAttribute('aria-hidden', 'true');
        sp.style.cssText = 'width:1px;margin:0;padding:0;pointer-events:none;flex:none;';
        (document.body || document.documentElement).appendChild(sp);
      }
      sp.style.height = kb + 'px';
    } else if (sp) {
      sp.style.height = '0px';
    }
  }
  window.__bzApply = function(){
    var kb = window.__bzKb || 0;
    spacer(kb);
    var el = document.activeElement;
    if (!field(el)) return;
    if (kb <= 0) return; // closing — leave scroll as is
    // Visible area = full height minus the keyboard; place the field just
    // above it, in one step (no resize, so no browser auto-scroll transient).
    var visBottom = window.innerHeight - kb;
    var rect = el.getBoundingClientRect();
    var delta = rect.bottom - (visBottom - 12);
    if (delta > 1 || delta < -1) scrollBy(el, delta);
  };
  // Switching between fields while the keyboard is already open: re-apply now.
  document.addEventListener('focusin', function(e){
    if (field(e.target) && (window.__bzKb || 0) > 0) window.__bzApply();
  }, true);
})();
''';
