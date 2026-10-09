// ignore_for_file: avoid_print
// ============================================================
// GEN VAULT — bake every "gray part" secret into the native vault
// ============================================================
// The gray-part strings (User-Agent fragments, the WebView JS
// injections, the notification-screen copy, the push-channel
// identity) used to live either as plaintext literals in Dart or as
// position_xor arrays that the DART codec (lib/midway/cipher/unmask.dart)
// could reveal — so both a `strings` dump AND a Dart-side decode would
// surface them. This generator moves the single source of truth into
// the native crate:
//
//   • android/rust/relay_transport/src/vault.rs  — every secret, XOR
//     encoded with an INDEPENDENT vault salt, decoded only inside the
//     .so. Plus the 32-byte session key (also encoded).
//
//   • lib/midway/vault/vault_blobs.dart — NO secret strings. Only the
//     stable key ids and the session key (byte-XOR encoded with a
//     separate Dart salt). The session key alone is useless: the
//     ciphertext it decrypts only ever comes back from the .so, freshly
//     re-encrypted with a per-call random nonce.
//
// On Android every consumer pulls its strings through `NativeVault`,
// which calls `bb_vault_fetch(key, nonce)`; the .so returns the secret
// re-encrypted under (sessionKey, nonce) as hex, and Dart decrypts it at
// the point of use. Nothing crosses the FFI boundary in the clear and no
// decodable copy ships in the Dart image.
//
// UA fragment VALUES are recovered from the current masked_bytes arrays
// via the existing unlock* accessors, so the forged UA stays byte-for-
// byte identical after migration. Run BEFORE stripping masked_bytes.
//
//   dart run tool/gen_vault.dart
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/midway/brief/masked_bytes.dart' as mb;

// ─────────────────────────────────────────────────────────────
// Codec parameters — position_xor family (matches unmask.dart shape
// with independent salts). Rotating a salt only requires re-running
// this generator; the Rust + Dart decoders are emitted from here.
// ─────────────────────────────────────────────────────────────
const int _weyl = 0x9E3779B1;

// Rust-side vault salt (secrets + session key live in the .so).
const List<int> _rustSalt = <int>[
  0x5a, 0xc3, 0x1f, 0x88, 0x74, 0x2e, 0xb6, 0x09,
  0xd1, 0x4c, 0xa7, 0x63, 0x30, 0xfe, 0x95, 0x2b,
  0x81, 0x17, 0xda, 0x6f, 0x4e, 0xc0, 0x38, 0x9d,
];
const int _rustStreamLen = 40;

// Dart-side salt — only the session key is encoded with it.
const List<int> _dartSalt = <int>[
  0xb7, 0x22, 0x6d, 0xf4, 0x19, 0x8c, 0x50, 0xab,
  0x3e, 0xc9, 0x71, 0x04, 0x96, 0x5f, 0xe2, 0x48,
  0x1d, 0xa0, 0x33, 0x7c,
];
const int _dartStreamLen = 36;

// The 32-byte session key. Shared raw value between Rust + Dart; each
// side stores it encoded under its own salt. The transit cipher keys
// its keystream off (sessionKey, per-call nonce).
const List<int> _sessionKey = <int>[
  0x27, 0x9b, 0x44, 0xe1, 0x6a, 0x0f, 0xbd, 0x52,
  0x8e, 0x31, 0xc6, 0x7a, 0x15, 0xd8, 0x43, 0x9f,
  0x60, 0xab, 0x0c, 0x74, 0xe9, 0x36, 0x58, 0xc2,
  0x8d, 0x1e, 0xf7, 0x40, 0xa3, 0x6b, 0x55, 0x92,
];

// ─────────────────────────────────────────────────────────────
// Secret registry. The key id is the FFI contract between Dart and
// Rust — keep the numbers stable.
// ─────────────────────────────────────────────────────────────
class _Secret {
  const _Secret(this.id, this.name, this.value);
  final int id;
  final String name; // UPPER_SNAKE → VAULT_<NAME> in Rust, kVault<Camel> in Dart
  final String value;
}

List<_Secret> _registry() {
  // UA fragments recovered from the live masked_bytes arrays, with the
  // generic code-unit seeds as the fallback if an array is empty.
  String ua(String Function() unlock, String seed) {
    final String v = unlock();
    return v.isNotEmpty ? v : seed;
  }

  return <_Secret>[
    // ── User-Agent fragments (Android assembly) ──────────────
    _Secret(1, 'UA_PRODUCT', ua(mb.unlockUaProduct, 'Mozilla/5.0')),
    _Secret(2, 'UA_LINUX_OPEN', ua(mb.unlockUaLinuxOpen, '(Linux; Android')),
    _Secret(3, 'UA_BUILD_LABEL', ua(mb.unlockUaBuildLabel, ' Build/')),
    _Secret(4, 'UA_BUILD_CLOSE', ua(mb.unlockUaBuildClose, ')')),
    _Secret(5, 'UA_ENGINE_LABEL', ua(mb.unlockUaEngineLabel, ' AppleWebKit/')),
    _Secret(6, 'UA_ENGINE_TAIL', ua(mb.unlockUaEngineTail, ' (KHTML, like Gecko)')),
    _Secret(7, 'UA_CHROME_LABEL', ua(mb.unlockUaChromeLabel, ' Chrome/')),
    _Secret(8, 'UA_MOBILE_SAFARI', ua(mb.unlockUaMobileSafari, ' Mobile Safari/')),
    _Secret(9, 'UA_CHROME_VERSION', ua(mb.unlockChromeVersion, '149.0.7827.163')),
    _Secret(10, 'UA_WEBKIT_VERSION', ua(mb.unlockWebkitVersion, '537.36')),

    // ── WebView JS injections ────────────────────────────────
    _Secret(20, 'JS_KEYBOARD', _jsKeyboard),
    _Secret(21, 'JS_PERCH_CALL',
        'window.__bzPerch&&window.__bzPerch(window.__bzKbShare||0);'),
    // %SHARE% is replaced on the Dart side with the clamped fraction.
    _Secret(22, 'JS_KBSHARE_TPL',
        'window.__bzKbShare=%SHARE%;window.__bzPerch&&window.__bzPerch(window.__bzKbShare);'),

    // ── Notification-promo screen copy ───────────────────────
    _Secret(30, 'NOTIF_TITLE', 'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS'),
    _Secret(31, 'NOTIF_SUBTITLE', 'Stay tuned for special offers and rewards'),
    _Secret(32, 'NOTIF_ALLOW', 'ALLOW'),
    _Secret(33, 'NOTIF_SKIP', 'SKIP'),

    // ── Push channel identity ────────────────────────────────
    _Secret(40, 'PUSH_CHANNEL_ID', 'ember_alerts'),
    _Secret(41, 'PUSH_CHANNEL_NAME', 'Offers & Rewards'),
    _Secret(42, 'PUSH_CHANNEL_DESC', 'Updates and offers'),
    _Secret(43, 'PUSH_SMALL_ICON', '@drawable/ic_notification'),
  ];
}

// The keyboard-seating script (verbatim source of truth — removed from
// lib/midway/rigging/inject_kit.dart and served from the vault instead).
const String _jsKeyboard = r'''
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

// ─────────────────────────────────────────────────────────────
// position_xor byte codec (shared shape; parametrised by salt/len).
// ─────────────────────────────────────────────────────────────
Uint8List _buildStream(List<int> salt, int streamLen) {
  int acc = 0x243F6A88;
  for (int i = 0; i < salt.length; i++) {
    acc = (acc + salt[i] * (i + 1) + _weyl) & 0xFFFFFFFF;
  }
  int state = acc == 0 ? _weyl : acc;
  final Uint8List stream = Uint8List(streamLen);
  for (int i = 0; i < streamLen; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    stream[i] = (state >> 16) & 0xFF;
  }
  return stream;
}

int _posMask(int i) => ((i * _weyl) >> 16) & 0xFF;

List<int> _encode(List<int> src, List<int> salt, int streamLen) {
  final Uint8List stream = _buildStream(salt, streamLen);
  final Uint8List out = Uint8List(src.length);
  for (int i = 0; i < src.length; i++) {
    out[i] = (src[i] ^ stream[i % streamLen] ^ _posMask(i)) & 0xFF;
  }
  return out;
}

bool _roundTrips(List<int> src, List<int> salt, int streamLen) {
  final List<int> enc = _encode(src, salt, streamLen);
  final List<int> dec = _encode(enc, salt, streamLen); // symmetric
  if (dec.length != src.length) return false;
  for (int i = 0; i < src.length; i++) {
    if (dec[i] != src[i]) return false;
  }
  return true;
}

String _rustArray(List<int> bytes) {
  final StringBuffer buf = StringBuffer('&[');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('\n    ');
    buf.write('0x${bytes[i].toRadixString(16).padLeft(2, '0')}, ');
  }
  buf.write('\n]');
  return buf.toString();
}

String _dartArray(List<int> bytes) {
  final StringBuffer buf = StringBuffer('<int>[');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 12 == 0) buf.write('\n  ');
    buf.write('0x${bytes[i].toRadixString(16).padLeft(2, '0')}, ');
  }
  buf.write('\n]');
  return buf.toString();
}

String _camel(String upperSnake) {
  final List<String> parts = upperSnake.toLowerCase().split('_');
  final StringBuffer b = StringBuffer(parts.first);
  for (int i = 1; i < parts.length; i++) {
    b.write(parts[i][0].toUpperCase() + parts[i].substring(1));
  }
  return b.toString();
}

void main() {
  final List<_Secret> secrets = _registry();

  // Validate: unique ids, round-trip every secret + the session key.
  final Set<int> ids = <int>{};
  for (final _Secret s in secrets) {
    if (!ids.add(s.id)) {
      stderr.writeln('vault: duplicate id ${s.id} (${s.name})');
      exit(64);
    }
    if (!_roundTrips(utf8.encode(s.value), _rustSalt, _rustStreamLen)) {
      stderr.writeln('vault: ${s.name} does not round-trip (rust)');
      exit(64);
    }
  }
  if (!_roundTrips(_sessionKey, _rustSalt, _rustStreamLen) ||
      !_roundTrips(_sessionKey, _dartSalt, _dartStreamLen)) {
    stderr.writeln('vault: session key does not round-trip');
    exit(64);
  }

  _writeRust(secrets);
  _writeDart(secrets);

  print('wrote vault: ${secrets.length} secrets, '
      'rustSalt ${_rustSalt.length}B/len$_rustStreamLen, '
      'dartSalt ${_dartSalt.length}B/len$_dartStreamLen');
}

void _writeRust(List<_Secret> secrets) {
  final StringBuffer o = StringBuffer();
  o.writeln('// ============================================================');
  o.writeln('// VAULT — generated by tool/gen_vault.dart. Do NOT hand-edit.');
  o.writeln('// ============================================================');
  o.writeln('// Every gray-part secret, XOR-encoded with an independent vault');
  o.writeln('// salt (position_xor family). Decoded only inside the .so; the');
  o.writeln('// FFI layer (lib.rs) re-encrypts each result under the session');
  o.writeln('// key + a per-call nonce before it crosses back to Dart.');
  o.writeln();
  o.writeln('const WEYL: u32 = 0x9E37_79B1;');
  o.writeln('const STREAM_LEN: usize = $_rustStreamLen;');
  o.writeln();
  o.write('const SALT: &[u8] = ');
  o.write(_rustArray(_rustSalt));
  o.writeln(';');
  o.writeln();
  o.write('const SESSION_KEY: &[u8] = ');
  o.write(_rustArray(_encode(_sessionKey, _rustSalt, _rustStreamLen)));
  o.writeln(';');
  o.writeln();
  for (final _Secret s in secrets) {
    o.write('const VAULT_${s.name}: &[u8] = ');
    o.write(_rustArray(_encode(utf8.encode(s.value), _rustSalt, _rustStreamLen)));
    o.writeln(';');
    o.writeln();
  }

  o.writeln(r'''
fn keystream() -> [u8; STREAM_LEN] {
    let mut acc: u32 = 0x243F_6A88;
    for (i, &b) in SALT.iter().enumerate() {
        acc = acc
            .wrapping_add((b as u32).wrapping_mul((i as u32) + 1))
            .wrapping_add(WEYL);
    }
    let mut state: u32 = if acc == 0 { WEYL } else { acc };
    let mut stream = [0u8; STREAM_LEN];
    for slot in stream.iter_mut() {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        *slot = ((state >> 16) & 0xFF) as u8;
    }
    stream
}

#[inline]
fn position_mask(i: usize) -> u8 {
    (((i as u64).wrapping_mul(WEYL as u64) >> 16) & 0xFF) as u8
}

fn reveal(encoded: &[u8]) -> Vec<u8> {
    let stream = keystream();
    let mut out = Vec::with_capacity(encoded.len());
    for (i, &byte) in encoded.iter().enumerate() {
        out.push(byte ^ stream[i % STREAM_LEN] ^ position_mask(i));
    }
    out
}

pub(crate) fn session_key() -> Vec<u8> {
    reveal(SESSION_KEY)
}
''');

  o.writeln('/// Decode the secret for `key`, or an empty vec for an unknown id.');
  o.writeln('pub(crate) fn secret(key: u32) -> Vec<u8> {');
  o.writeln('    match key {');
  for (final _Secret s in secrets) {
    o.writeln('        ${s.id} => reveal(VAULT_${s.name}),');
  }
  o.writeln('        _ => Vec::new(),');
  o.writeln('    }');
  o.writeln('}');

  const String path = 'android/rust/relay_transport/src/vault.rs';
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(o.toString());
  print('wrote: $path');
}

void _writeDart(List<_Secret> secrets) {
  final StringBuffer o = StringBuffer();
  o.writeln('// ============================================================');
  o.writeln('// VAULT BLOBS — generated by tool/gen_vault.dart. Do NOT hand-edit.');
  o.writeln('// ============================================================');
  o.writeln('// Contains NO secret strings. Only the stable FFI key ids and the');
  o.writeln('// 32-byte session key (byte-XOR encoded with an independent Dart');
  o.writeln('// salt). The session key is useless on its own: it only decrypts');
  o.writeln('// ciphertext that the .so returns, freshly re-keyed with a random');
  o.writeln('// per-call nonce.');
  o.writeln();
  o.writeln("import 'dart:typed_data';");
  o.writeln();
  o.writeln('// Stable key ids — must match VAULT_* in');
  o.writeln('// android/rust/relay_transport/src/vault.rs');
  for (final _Secret s in secrets) {
    o.writeln('const int kVault${_capital(_camel(s.name))} = ${s.id};');
  }
  o.writeln();
  o.writeln('const int _weyl = 0x9E3779B1;');
  o.writeln('const int _streamLen = $_dartStreamLen;');
  o.write('const List<int> _salt = ');
  o.write(_dartArray(_dartSalt));
  o.writeln(';');
  o.writeln();
  o.write('const List<int> _sessionKeyEnc = ');
  o.write(_dartArray(_encode(_sessionKey, _dartSalt, _dartStreamLen)));
  o.writeln(';');
  o.writeln();
  o.writeln(r'''Uint8List _stream() {
  int acc = 0x243F6A88;
  for (int i = 0; i < _salt.length; i++) {
    acc = (acc + _salt[i] * (i + 1) + _weyl) & 0xFFFFFFFF;
  }
  int state = acc == 0 ? _weyl : acc;
  final Uint8List s = Uint8List(_streamLen);
  for (int i = 0; i < _streamLen; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    s[i] = (state >> 16) & 0xFF;
  }
  return s;
}

int _posMask(int i) => ((i * _weyl) >> 16) & 0xFF;

/// Decode the session key to its raw 32 bytes.
Uint8List revealVaultSessionKey() {
  final Uint8List stream = _stream();
  final Uint8List out = Uint8List(_sessionKeyEnc.length);
  for (int i = 0; i < _sessionKeyEnc.length; i++) {
    out[i] = (_sessionKeyEnc[i] ^ stream[i % _streamLen] ^ _posMask(i)) & 0xFF;
  }
  return out;
}''');
  o.writeln();

  const String path = 'lib/midway/vault/vault_blobs.dart';
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(o.toString());
  print('wrote: $path');
}

String _capital(String camel) => camel[0].toUpperCase() + camel.substring(1);
