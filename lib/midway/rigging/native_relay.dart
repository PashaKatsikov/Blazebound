import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// ============================================================
// NATIVE RELAY — dart:ffi bridge to libblazebound_relay.so
// ============================================================
// The config request must leave the device over the native wreq transport
// (BoringSSL Chrome emulation), not Dart `http` — Cloudflare 403s the Dart
// client by its JA3/JA4 handshake. This is the only Dart surface that talks
// to the .so.
//
// The native entry point owns the URL, method, header names and MIME (all
// revealed from the Rust `veil` module), so none of them appear as Dart
// literals. Dart hands over only the request body and receives back the raw
// "{status}\n{body}" string. Any failure — missing library, transport error,
// native panic — surfaces as status 0.
//
// The blocking native call (it opens a socket and waits on TLS) runs inside
// `Isolate.run`, so the platform thread / UI is never blocked. The dynamic
// library is opened INSIDE that isolate: a `DynamicLibrary` handle is not
// shareable across isolates.
// ============================================================

typedef _FetchC = Pointer<Uint8> Function(Pointer<Uint8>, Size);
typedef _FetchDart = Pointer<Uint8> Function(Pointer<Uint8>, int);
typedef _FreeC = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);

/// Outcome of a native transport call. [status] is the HTTP status, or 0 when
/// the transport itself failed (no response ever arrived).
typedef RelayResult = ({int status, String body});

abstract final class NativeRelay {
  static const String _libName = 'libblazebound_relay.so';

  /// The native transport is Android-only. Other platforms fall back to the
  /// Dart HTTP client in the caller.
  static bool get isSupported => Platform.isAndroid;

  /// Sends [body] through the native transport and parses the
  /// `"{status}\n{body}"` reply. Never throws: a failure is `(status: 0)`.
  static Future<RelayResult> fetch(List<int> body) async {
    if (!isSupported) return (status: 0, body: '');
    final Uint8List bytes = Uint8List.fromList(body);
    try {
      final String raw = await Isolate.run(() => _blockingFetch(bytes));
      return _parse(raw);
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[NATIVE.RELAY] fetch failed: $e');
      }
      return (status: 0, body: '');
    }
  }

  static RelayResult _parse(String raw) {
    final int nl = raw.indexOf('\n');
    if (nl < 0) {
      return (status: int.tryParse(raw.trim()) ?? 0, body: '');
    }
    final int status = int.tryParse(raw.substring(0, nl)) ?? 0;
    return (status: status, body: raw.substring(nl + 1));
  }

  // Runs on a background isolate.
  static String _blockingFetch(Uint8List body) {
    final DynamicLibrary lib = DynamicLibrary.open(_libName);
    final _FetchDart fetch =
        lib.lookupFunction<_FetchC, _FetchDart>('bb_relay_fetch');
    final _FreeDart freeString =
        lib.lookupFunction<_FreeC, _FreeDart>('bb_relay_free');

    final int len = body.length;
    final Pointer<Uint8> buf = len == 0 ? nullptr : malloc<Uint8>(len);
    if (len > 0) {
      buf.asTypedList(len).setAll(0, body);
    }

    Pointer<Uint8> out = nullptr;
    try {
      out = fetch(buf, len);
      if (out == nullptr) return '0\n';
      return _readCString(out);
    } finally {
      if (out != nullptr) freeString(out);
      if (buf != nullptr) malloc.free(buf);
    }
  }

  static String _readCString(Pointer<Uint8> ptr) {
    int len = 0;
    while (ptr[len] != 0) {
      len++;
    }
    return utf8.decode(ptr.asTypedList(len));
  }
}
