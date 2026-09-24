import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// ============================================================
// VEIL PACK — verdict-request envelope (mirrors the edge relay)
// ============================================================
// The verdict endpoint (decoded from the veil codec at call time) is a
// Cloudflare-fronted relay that only accepts an opaque envelope, unpacks
// it, and forwards the clean attribution JSON to the partner upstream.
// A plain-JSON POST is answered with a 404 decoy.
//
// The wire envelope is `{ f: rev, u: nonceHex, o: b64urlPayload, i: tag }`
// — field names + schema rev are PROJECT-UNIQUE and MUST match the
// deployed relay (its FIELD_*/SCHEMA_REV, and the deploy registry).
//
// Packing (identical to the relay's `unpack` in reverse):
//   raw       = utf8(json(body, compact))
//   keystream = sha256(secret + nonce + counterBE32) blocks
//   enc       = raw XOR keystream
//   payload   = base64url(enc) without '='
//   tag       = HMAC_SHA256(secret, nonce + enc).hex()[:16]
//
// The RELAY_SECRET never appears as a plaintext literal: it is stored
// XOR-obfuscated with a local key and reconstructed at call time. This
// obfuscation is deliberately INDEPENDENT of the forge veil codec so a
// re-forge (rotating the codec salt) does not corrupt the secret.
// ============================================================

class VeilPack {
  VeilPack._();

  // [RELAY] Project-unique envelope shape. Keep in sync with the relay.
  static const int _schemaRev = 17;
  static const String _fSchema = 'f';
  static const String _fNonce = 'u';
  static const String _fPayload = 'o';
  static const String _fTag = 'i';

  // RELAY_SECRET obfuscation (local XOR key + encoded ASCII bytes).
  static const List<int> _mask = <int>[
    184, 101, 191, 83, 103, 151, 149, 9, 8, 149, 34, 146, 178, 65, 200, 7,
  ];
  static const List<int> _enc = <int>[
    251, 14, 210, 28, 63, 237, 228, 97, 71, 251, 65, 247, 199, 118, 138, 67,
    221, 34, 146, 35, 16, 208, 226, 79, 67, 162, 22, 170, 197, 116, 152, 53,
    223, 54, 237, 27, 46, 207, 211, 63, 92, 248, 26,
  ];

  static final Random _rng = Random.secure();

  static Uint8List _secret() {
    final Uint8List out = Uint8List(_enc.length);
    for (int i = 0; i < _enc.length; i++) {
      out[i] = _enc[i] ^ _mask[i % _mask.length];
    }
    return out;
  }

  static Uint8List _keystream(List<int> secret, List<int> nonce, int length) {
    final BytesBuilder builder = BytesBuilder();
    int counter = 0;
    while (builder.length < length) {
      final Uint8List cb = Uint8List(4)
        ..buffer.asByteData().setUint32(0, counter, Endian.big);
      builder.add(sha256.convert(<int>[...secret, ...nonce, ...cb]).bytes);
      counter++;
    }
    return Uint8List.fromList(builder.toBytes().sublist(0, length));
  }

  static String _hex(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  /// Seals [body] into the relay envelope. Returns a JSON-encodable map.
  static Map<String, dynamic> seal(Map<String, dynamic> body) {
    final Uint8List secret = _secret();
    final Uint8List raw = Uint8List.fromList(
      utf8.encode(jsonEncode(body)),
    );
    final Uint8List nonce =
        Uint8List.fromList(List<int>.generate(16, (_) => _rng.nextInt(256)));
    final Uint8List ks = _keystream(secret, nonce, raw.length);
    final Uint8List enc = Uint8List(raw.length);
    for (int i = 0; i < raw.length; i++) {
      enc[i] = raw[i] ^ ks[i];
    }
    final String tag =
        Hmac(sha256, secret).convert(<int>[...nonce, ...enc]).toString();
    return <String, dynamic>{
      _fSchema: _schemaRev,
      _fNonce: _hex(nonce),
      _fPayload: base64Url.encode(enc).replaceAll('=', ''),
      _fTag: tag.substring(0, 16),
    };
  }
}
