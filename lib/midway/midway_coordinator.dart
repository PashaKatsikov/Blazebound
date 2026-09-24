import 'dart:async';
import 'dart:io';

import 'brief/midway_brief.dart';
import 'outcome/arrival.dart';
import 'rigging/push_channel.dart';
import 'rigging/attribution_feed.dart';
import 'rigging/keybox.dart';
import 'rigging/cold_link.dart';
import 'rigging/reach_probe.dart';
import 'rigging/ruling_call.dart';

// ============================================================
// MIDWAY COORDINATOR — single entry point for the boot decision
// ============================================================
// One method: `decide(onProgress)` returns an `Arrival` sealed type.
// The boot screen destructures via `switch (arrival)` and only there
// decides which route to push. No routing logic lives anywhere else.
//
// The decision pipeline branches on the persisted [RouteState]:
//
//   undecided (first launch)
//     ├─ no adapter       → OfflineArrival(returnsToGame: false)
//     ├─ DNS probe fails  → OfflineArrival(returnsToGame: false)
//     ├─ ruling approved  → save portal → PortalArrival(url)
//     └─ ruling rejected  → save native → GameArrival
//
//   portal (was in the WebView)
//     ├─ no adapter       → OfflineArrival(returnsToGame: false)
//     ├─ cold-tap URL     → PortalArrival(url, coldTap: true)
//     ├─ fresh cached URL → PortalArrival(cachedUrl)
//     ├─ ruling approved  → PortalArrival(freshUrl)
//     ├─ ruling rejected but cache exists
//     │                   → PortalArrival(cachedUrl)  (last-known-good)
//     └─ otherwise        → OfflineArrival(returnsToGame: false)
//
//   native (was in the game)
//     ├─ no adapter       → GameArrival                (never blocks)
//     ├─ ruling approved  → save portal → PortalArrival(url)
//     └─ ruling rejected  → GameArrival
//
// Concurrent boots are de-duplicated — the coordinator caches the
// in-flight future so two synchronous `decide()` calls (e.g. the boot
// screen briefly building twice) do not fire two ruling POSTs. The
// cache clears on completion so a Retry from the offline booth
// re-runs the pipeline in full.
// ============================================================

class MidwayCoordinator {
  MidwayCoordinator({
    required this.keystore,
    required this.probe,
    required this.pulse,
    required this.verdict,
    required this.alerts,
  });

  final KeyBox keystore;
  final ReachProbe probe;
  final AttributionFeed pulse;
  final RulingCall verdict;
  final PushChannel alerts;

  Future<Arrival>? _inFlight;

  Future<Arrival> decide({void Function(double)? onProgress}) {
    return _inFlight ??= _decide(onProgress ?? (_) {})
        .whenComplete(() => _inFlight = null);
  }

  Future<Arrival> _decide(void Function(double) onProgress) async {
    if (!MidwayBrief.credentialsReady) {
      onProgress(1);
      return const GameArrival();
    }

    alerts.onTokenChanged = _refreshOnTokenChange;

    // Cold-boot push tap always wins.
    final String? coldTapUrl = await ColdLink.consume(keystore);
    if (coldTapUrl != null && coldTapUrl.isNotEmpty) {
      if (!await probe.canDialOut()) {
        return const OfflineArrival(returnsToGame: false);
      }
      await keystore.saveRoute(RouteState.portal);
      unawaited(_fireAndForget());
      onProgress(1);
      return PortalArrival(coldTapUrl, coldTap: true);
    }

    onProgress(0.15);
    return switch (keystore.route) {
      RouteState.undecided => _decideFirstLaunch(onProgress),
      RouteState.portal => _decideReturningPortal(onProgress),
      RouteState.native => _decideReturningGame(onProgress),
    };
  }

  Future<Arrival> _decideFirstLaunch(void Function(double) onProgress) async {
    if (!await probe.hasAdapter()) {
      return const OfflineArrival(returnsToGame: false);
    }
    onProgress(0.3);
    try {
      await alerts.boot();
    } catch (_) {}
    if (!await probe.canDialOut()) {
      return const OfflineArrival(returnsToGame: false);
    }
    onProgress(0.5);
    await pulse.start();
    await pulse.awaitSignals(
      installSeconds: MidwayBrief.firstInstallAwaitSeconds,
    );
    onProgress(0.75);
    final Ruling answer = await _requestRuling();
    onProgress(1);
    if (answer.hasDestination) {
      await keystore.saveRoute(RouteState.portal);
      return PortalArrival(answer.url!);
    }
    await keystore.saveRoute(RouteState.native);
    return const GameArrival();
  }

  Future<Arrival> _decideReturningPortal(
    void Function(double) onProgress,
  ) async {
    if (!await probe.hasAdapter() || !await probe.canDialOut()) {
      return const OfflineArrival(returnsToGame: false);
    }
    final String? pending = await keystore.consumePendingUrl();
    if (pending != null && pending.isNotEmpty) {
      onProgress(1);
      return PortalArrival(pending);
    }
    final String? cached = await keystore.cachedDestination();
    if (cached != null && !keystore.cachedDestinationExpired) {
      onProgress(1);
      return PortalArrival(cached);
    }

    await Future.wait<void>(<Future<void>>[
      alerts.boot(),
      pulse.start(),
    ]);
    onProgress(0.6);
    await pulse.awaitSignals(
      installSeconds: MidwayBrief.returningInstallAwaitSeconds,
    );
    final Ruling answer = await _requestRuling();
    onProgress(1);
    if (answer.hasDestination) return PortalArrival(answer.url!);
    if (cached != null) return PortalArrival(cached);
    return const OfflineArrival(returnsToGame: false);
  }

  Future<Arrival> _decideReturningGame(
    void Function(double) onProgress,
  ) async {
    if (!await probe.hasAdapter()) {
      onProgress(1);
      return const GameArrival();
    }
    await Future.wait<void>(<Future<void>>[
      alerts.boot(),
      pulse.start(),
    ]);
    if (!await probe.canDialOut()) {
      onProgress(1);
      return const GameArrival();
    }
    onProgress(0.55);
    await pulse.awaitSignals(
      installSeconds: MidwayBrief.returningInstallAwaitSeconds,
    );
    final Ruling answer = await _requestRuling();
    onProgress(1);
    if (!answer.hasDestination) return const GameArrival();
    await keystore.saveRoute(RouteState.portal);
    return PortalArrival(answer.url!);
  }

  Future<Ruling> _requestRuling({String? token}) async {
    final Map<String, dynamic> body = await pulse.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? alerts.token,
    );
    return verdict.ask(body);
  }

  Future<void> _fireAndForget() async {
    try {
      await Future.wait<void>(<Future<void>>[
        alerts.boot(),
        pulse.start(),
      ]);
      await pulse.awaitSignals(
        installSeconds: MidwayBrief.returningInstallAwaitSeconds,
      );
      await _requestRuling();
    } catch (_) {}
  }

  Future<void> _refreshOnTokenChange(String token) async {
    try {
      await _requestRuling(token: token);
    } catch (_) {}
  }
}
