// ============================================================
// ARRIVAL — routing outcome of the boot pipeline (sealed types)
// ============================================================
// The pipeline yields exactly ONE sealed subtype. The boot screen
// destructures the result with a `switch` and only there chooses
// the screen to push — no routing branch lives anywhere else.
//
// A sealed hierarchy compiles differently from an `enum` + if/else
// chain, so the emitted code reads unlike sibling apps that lean on
// the enum-and-branch shape.
// ============================================================

/// Parsed answer from the ruling endpoint.
///
/// Wire keys `{ok, url, expires, message}` are mapped verbatim —
/// the backend contract fixes those exact spellings.
class Ruling {
  const Ruling({
    required this.approved,
    this.url,
    this.expiresAt,
    this.note,
  });

  factory Ruling.fromJson(Map<String, dynamic> json) {
    final dynamic rawExpiry = json['expires'];
    return Ruling(
      approved: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: json['message']?.toString(),
    );
  }

  factory Ruling.rejected(String note) =>
      Ruling(approved: false, note: note);

  final bool approved;
  final String? url;
  final int? expiresAt;
  final String? note;

  bool get hasDestination => approved && url != null && url!.isNotEmpty;
}

/// Persisted routing memory across launches.
///
/// Wire values are stored under a project-scoped keystore key. Do
/// NOT rename the wire strings — legacy installs still hold the old
/// value.
enum RouteState {
  undecided,
  portal,
  native;

  String get wireValue => switch (this) {
        RouteState.undecided => 'undecided',
        RouteState.portal => 'portal',
        RouteState.native => 'native',
      };

  static RouteState parse(String? raw) => switch (raw) {
        'portal' || 'web' => RouteState.portal,
        'native' || 'game' => RouteState.native,
        _ => RouteState.undecided,
      };
}

/// Sealed outcome of the boot pipeline. Adding a subtype forces a
/// new case label at every dispatch site, so a branch can never be
/// silently forgotten.
sealed class Arrival {
  const Arrival();
}

/// Show the native game.
final class GameArrival extends Arrival {
  const GameArrival();
}

/// Show the WebView portal at [url].
///
/// [coldTap] is true only when the launch came from a cold-boot push
/// tap — the URL is taken from the intent payload, not the cache, and
/// the boot animation is shortened.
final class PortalArrival extends Arrival {
  const PortalArrival(this.url, {this.coldTap = false});

  final String url;
  final bool coldTap;
}

/// Show the no-connection screen. Retry rebuilds the boot pipeline.
///
/// [returnsToGame] is true when the user was previously in native
/// mode — a retry after Wi-Fi returns can jump straight to the game
/// instead of re-running the whole ruling pipeline.
final class OfflineArrival extends Arrival {
  const OfflineArrival({required this.returnsToGame});

  final bool returnsToGame;
}
