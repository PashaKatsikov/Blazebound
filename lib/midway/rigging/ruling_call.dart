import 'dart:convert';

import '../brief/midway_brief.dart';
import '../outcome/arrival.dart';
import 'keybox.dart';
import 'net_agent.dart';
import 'seal_pack.dart';

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
      // The endpoint is an edge relay that only accepts an opaque
      // envelope (plain JSON is answered with a 404 decoy). Seal the
      // attribution body before it leaves the device.
      final Map<String, dynamic> envelope = SealPack.seal(body);
      final dynamic response = await netAgent
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(envelope),
          )
          .timeout(Duration(seconds: MidwayBrief.verdictTimeoutSeconds));

      if (response.statusCode != 200) {
        return Ruling.rejected('http_${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return Ruling.rejected('malformed');
      final Ruling ruling = Ruling.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (ruling.hasDestination) {
        await _keystore.cacheDestination(ruling.url!, ruling.expiresAt);
      }
      return ruling;
    } catch (e) {
      return Ruling.rejected('network:$e');
    }
  }
}
