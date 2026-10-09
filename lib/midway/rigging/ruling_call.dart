import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../brief/midway_brief.dart';
import '../outcome/arrival.dart';
import 'keybox.dart';
import 'native_relay.dart';
import 'net_agent.dart';

// ============================================================
// RULING CALL — POST the assembled body, cache the answer
// ============================================================
// The backend is the single source of truth for the routing
// decision. On an approved response we cache both the URL AND its
// expiry so returning launches can skip the network call while the
// URL is still fresh. On any failure — HTTP error, timeout, malformed
// JSON — we return a rejected ruling; the coordinator turns that into
// a game arrival (or an offline arrival if the network is down).
// ============================================================

class RulingCall {
  RulingCall(this._keystore);

  final KeyBox _keystore;

  Future<Ruling> ask(Map<String, dynamic> body) async {
    final String endpoint = MidwayBrief.endpointUrl;
    if (endpoint.isEmpty) {
      return Ruling.rejected('endpoint_missing');
    }

    try {
      // The body leaves the device as plain JSON — no app-level envelope.
      // Confidentiality is provided at the transport layer only (the native
      // wreq/BoringSSL TLS connection); nothing is sealed before sending.
      final String payload = jsonEncode(body);

      final int statusCode;
      final String responseBody;
      if (NativeRelay.isSupported) {
        // Native wreq transport: BoringSSL Chrome emulation defeats the
        // Cloudflare JA3/JA4 filter. The URL/method/headers/MIME are owned
        // by the native side; we pass only the plain JSON body. Status 0 means
        // the transport failed (treated as a rejected ruling below).
        final RelayResult relay = await NativeRelay.fetch(utf8.encode(payload))
            .timeout(Duration(seconds: MidwayBrief.verdictTimeoutSeconds));
        statusCode = relay.status;
        responseBody = relay.body;
      } else {
        final dynamic response = await netAgent
            .post(
              Uri.parse(endpoint),
              headers: const <String, String>{
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: payload,
            )
            .timeout(Duration(seconds: MidwayBrief.verdictTimeoutSeconds));
        statusCode = response.statusCode as int;
        responseBody = response.body as String;
      }

      if (kDebugMode) {
        final String snippet = responseBody.length > 300
            ? responseBody.substring(0, 300)
            : responseBody;
        debugPrint('[MIDWAY.RULING] native=${NativeRelay.isSupported} '
            'status=$statusCode bodyLen=${responseBody.length} body=$snippet');
      }

      if (statusCode != 200) {
        return Ruling.rejected('http_$statusCode');
      }

      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is! Map) return Ruling.rejected('malformed');
      final Ruling ruling = Ruling.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (kDebugMode) {
        debugPrint('[MIDWAY.RULING] approved=${ruling.approved} '
            'url=${ruling.url} expires=${ruling.expiresAt}');
      }

      if (ruling.hasDestination) {
        await _keystore.cacheDestination(ruling.url!, ruling.expiresAt);
      }
      return ruling;
    } catch (e) {
      if (kDebugMode) debugPrint('[MIDWAY.RULING] EXCEPTION $e');
      return Ruling.rejected('network:$e');
    }
  }
}
