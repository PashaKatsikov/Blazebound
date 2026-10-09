import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'vault_blobs.dart';

// ============================================================
// NATIVE VAULT — dart:ffi bridge to the gray-part secret store
// ============================================================
// Every gray-part string (UA fragments, WebView JS injections, the
// notification-promo copy, the push-channel identity) lives XOR-encoded
// inside libblazebound_relay.so (see android/rust/.../vault.rs). Dart
// never holds a plaintext copy and never holds a decodable array of one.
//
// On each [get] call Dart hands the .so a stable key id plus a fresh random
// nonce; the native side decodes the secret and returns it RE-ENCRYPTED
// under (session key, nonce) as lowercase hex. Dart reverses that last step
// with the session key (decoded from `vault_blobs.dart`) and the same nonce.
// Because the nonce is random per call, the bytes on the wire differ every
// time, so a passive hook on the FFI return sees only noise — the plaintext
// exists for a single statement, at the point of use.
//
// The call is pure CPU (a few hundred bytes of XOR), so it runs synchronously
// on the caller's isolate — no network, no blocking. The native vault is
// Android-only; on other platforms [get] returns '' and each consumer keeps a
// harmless, non-campaign QA fallback.
// ============================================================

typedef _FetchC = Pointer<Uint8> Function(Uint32, Pointer<Uint8>, Size);
typedef _FetchDart = Pointer<Uint8> Function(int, Pointer<Uint8>, int);
typedef _FreeC = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);

abstract final class NativeVault {
  NativeVault._();

  static const String _libName = 'libblazebound_relay.so';
  static const int _weyl = 0x9E3779B1;
  static const int _nonceLen = 16;

  /// Android-only. Elsewhere [get] returns '' and consumers fall back.
  static bool get isSupported => Platform.isAndroid;

  static final Random _rng = Random.secure();

  static bool _tried = false;
  static _FetchDart? _fetch;
  static _FreeDart? _free;
  static Uint8List? _sk;

  static void _ensure() {
    if (_tried) return;
    _tried = true;
    try {
      final DynamicLibrary lib = DynamicLibrary.open(_libName);
      _fetch = lib.lookupFunction<_FetchC, _FetchDart>('bb_vault_fetch');
      _free = lib.lookupFunction<_FreeC, _FreeDart>('bb_vault_free');
      _sk = revealVaultSessionKey();
    } catch (_) {
      _fetch = null;
      _free = null;
      _sk = null;
    }
  }

  /// Returns the decrypted secret for [key], or '' on any failure / off
  /// Android. Fetches fresh every call — nothing is cached in the clear.
  static String get(int key) {
    if (!isSupported) return '';
    _ensure();
    final _FetchDart? fetch = _fetch;
    final _FreeDart? free = _free;
    final Uint8List? sk = _sk;
    if (fetch == null || free == null || sk == null) return '';

    final Uint8List nonce = _nonce();
    final Pointer<Uint8> nbuf = malloc<Uint8>(_nonceLen);
    Pointer<Uint8> out = nullptr;
    try {
      nbuf.asTypedList(_nonceLen).setAll(0, nonce);
      out = fetch(key, nbuf, _nonceLen);
      if (out == nullptr) return '';
      final String hex = _readCString(out);
      if (hex.isEmpty) return '';
      final Uint8List ct = _fromHex(hex);
      final Uint8List ks = _transit(sk, nonce, ct.length);
      final Uint8List plain = Uint8List(ct.length);
      for (int i = 0; i < ct.length; i++) {
        plain[i] = ct[i] ^ ks[i];
      }
      return utf8.decode(plain, allowMalformed: true);
    } catch (_) {
      return '';
    } finally {
      if (out != nullptr) free(out);
      malloc.free(nbuf);
    }
  }

  static Uint8List _nonce() {
    final Uint8List n = Uint8List(_nonceLen);
    for (int i = 0; i < _nonceLen; i++) {
      n[i] = _rng.nextInt(256);
    }
    return n;
  }

  static int _posMask(int i) => ((i * _weyl) >> 16) & 0xFF;

  /// Keystream keyed by (session key, nonce). Mirrors `transit_keystream` in
  /// android/rust/relay_transport/src/lib.rs byte-for-byte.
  static Uint8List _transit(Uint8List sk, Uint8List nonce, int len) {
    int acc = 0x243F6A88;
    for (int i = 0; i < sk.length; i++) {
      acc = (acc + sk[i] * (i + 1) + _weyl) & 0xFFFFFFFF;
    }
    for (int j = 0; j < nonce.length; j++) {
      acc = (acc + nonce[j] * (sk.length + j + 1) + _weyl) & 0xFFFFFFFF;
    }
    int state = acc == 0 ? _weyl : acc;
    final Uint8List out = Uint8List(len);
    for (int i = 0; i < len; i++) {
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= state >> 17;
      state ^= (state << 5) & 0xFFFFFFFF;
      state &= 0xFFFFFFFF;
      out[i] = (((state >> 16) & 0xFF) ^
              sk[i % sk.length] ^
              nonce[i % nonce.length] ^
              _posMask(i)) &
          0xFF;
    }
    return out;
  }

  static Uint8List _fromHex(String h) {
    final int n = h.length ~/ 2;
    final Uint8List out = Uint8List(n);
    for (int i = 0; i < n; i++) {
      out[i] = int.parse(h.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static String _readCString(Pointer<Uint8> ptr) {
    int len = 0;
    while (ptr[len] != 0) {
      len++;
    }
    return utf8.decode(ptr.asTypedList(len));
  }
}
