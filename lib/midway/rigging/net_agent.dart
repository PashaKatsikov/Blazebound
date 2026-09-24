import 'package:http/http.dart' as http;

import 'agent_string.dart';

// ============================================================
// NET AGENT — http.Client that always carries the forged UA
// ============================================================
// Every outbound HTTP call in the midway pipeline (ruling POST, GCD
// rescue, push-image fetch) goes through this client. The User-Agent
// header is written unconditionally so no request escapes with the
// default Dart `dart-io/x.y` UA — that literal is a well-known
// Flutter-shell fingerprint.
// ============================================================

class NetAgent extends http.BaseClient {
  NetAgent();

  final http.Client _transport = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = AgentString.userAgent;
    return _transport.send(request);
  }

  @override
  void close() => _transport.close();
}

/// Shared client instance — one per app, primed after
/// `AgentString.prime()` completes in `main()`.
final NetAgent netAgent = NetAgent();
