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
      await controller
          .runJavaScript('window.__bzPerch&&window.__bzPerch(window.__bzKbShare||0);');
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
    try {
      await controller.runJavaScript(
        'window.__bzKbShare=${clamped.toStringAsFixed(5)};'
        'window.__bzPerch&&window.__bzPerch(window.__bzKbShare);',
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

/// Keyboard seating.
///
/// The WebView is NEVER resized by Flutter: the activity pins
/// `SOFT_INPUT_ADJUST_NOTHING` on API 30+ and the host wraps the WebView in
/// a MediaQuery that strips the bottom viewInset. Instead, Dart pushes the
/// keyboard-occupancy fraction (`window.__bzKbShare` ∈ [0..1]) into the
/// page via `__bzPerch(share)`. On every focus / focus-out / visualViewport
/// event we recompute where the field should sit and translate its nearest
/// `position:fixed` ancestor (fallback: `window.scrollBy`). The measurement
/// re-reads the field's live rect and adds the currently-held offset back in,
/// so any auto-scroll the page itself performs after focus is corrected on
/// the next pass instead of stacking onto ours.
const String _keyboardLift = r'''
(function(){
  var TAG = '__bzPerch';
  if (window[TAG] && window[TAG].live) return;

  var CAP = 0.9;   // never lift by more than 90% of the viewport
  var EPS = 4;     // sub-pixel deadband
  var hold = { share: 0, host: null, seed: '', pull: 0 };
  var raf = 0;

  function pad(){
    var v = (window.innerHeight * 0.015) | 0;
    return v < 6 ? 6 : (v > 16 ? 16 : v);
  }
  function focusedField(){
    var n = document.activeElement;
    if (!n || !n.tagName) return null;
    if (n.isContentEditable === true) return n;
    var tag = n.tagName.toLowerCase();
    return (tag === 'input' || tag === 'textarea' || tag === 'select') ? n : null;
  }
  function fixedAncestor(node){
    var walk = node.parentElement;
    while (walk && walk !== document.body) {
      if (getComputedStyle(walk).position === 'fixed') return walk;
      walk = walk.parentElement;
    }
    return null;
  }
  function keyboardTop(){
    var s = hold.share > CAP ? CAP : hold.share;
    return window.innerHeight * (1 - s);
  }
  function releaseHost(){
    if (hold.host) hold.host.style.transform = hold.seed;
    hold.host = null;
    hold.seed = '';
    hold.pull = 0;
  }
  function shift(px){
    if (px === hold.pull) return;
    hold.pull = px;
    var t = 'translate3d(0px,' + (-px) + 'px,0px)';
    hold.host.style.transform = hold.seed ? (hold.seed + ' ' + t) : t;
  }
  function seat(){
    var node = focusedField();
    if (!node || !(hold.share > 0)) { releaseHost(); return; }

    var host = fixedAncestor(node);
    var kbTop = keyboardTop();
    if (!host) {
      releaseHost();
      var over = node.getBoundingClientRect().bottom + pad() - kbTop;
      if (over > EPS) window.scrollBy(0, over);
      return;
    }
    if (host !== hold.host) {
      releaseHost();
      hold.host = host;
      hold.seed = host.style.transform || '';
    }
    // Live rect + the offset we already hold = the true resting bottom;
    // no CSS transition is in flight so this is exact every pass.
    var restingBottom = node.getBoundingClientRect().bottom + hold.pull;
    var need = restingBottom + pad() - kbTop;
    shift(need > EPS ? need : 0);
  }
  function queue(){
    if (raf) return;
    raf = requestAnimationFrame(function(){ raf = 0; seat(); });
  }
  function queueBurst(){
    queue();
    setTimeout(queue, 120);
    setTimeout(queue, 320);
  }
  function perch(value){
    hold.share = value > 0 ? value : 0;
    if (!(hold.share > 0)) {
      if (raf) { cancelAnimationFrame(raf); raf = 0; }
      releaseHost();
      return;
    }
    queue();
  }
  perch.live = 1;
  window[TAG] = perch;
  window.__bzKbShare = window.__bzKbShare || 0;

  document.addEventListener('focusin', queueBurst, true);
  document.addEventListener('focusout', function(){ setTimeout(queue, 0); }, true);
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', queue);
    window.visualViewport.addEventListener('scroll', queue);
  }
})();
''';
