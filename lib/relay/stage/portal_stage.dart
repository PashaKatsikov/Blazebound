import 'dart:async';
import 'dart:io';
import 'dart:ui' show FlutterView;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import '../wire/device_signature.dart';
import '../wire/pulse_probe.dart';
import '../wire/web_scripts.dart';
import 'offline_stage.dart';

// ============================================================
// PORTAL STAGE — the WebView shell (gray content)
// ============================================================
// Hosts the destination URL with:
//   • forged device UA (identical to the HTTP client's UA)
//   • both orientations, immersive system UI
//   • external-scheme hand-off (tel:, mailto:, intent://)
//   • redirect-loop recovery (main-frame -1007 / -9 with a
//     bounded retry)
//   • live connectivity guard (debounced)
//   • warm push URL delivery via [AlertChannel.onIncomingUrl]
//   • native file chooser via MethodChannel (no file_picker dep)
//   • JS behaviours composed by `WebScripts.installAll`
//
// NOTE: There is NO client-side classification of the partner
// site (no deposit/cashier/register/login regex, no funnel event
// emission). Any funnel needed by the business must live server
// side; the client is a dumb shell.
// ============================================================

class PortalStage extends StatefulWidget {
  const PortalStage({
    super.key,
    required this.url,
    required this.keystore,
    required this.alerts,
  });

  final String url;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _retryCounter = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  // Camera-cutout padding (dp) fed from native displayCutout. Deliberately
  // excludes the nav bar so the WebView width never changes when the nav bar
  // appears with the keyboard.
  EdgeInsets _cutout = EdgeInsets.zero;

  // Fraction of the visible viewport currently taken by the soft keyboard
  // (0..1). Measured from view.viewInsets.bottom / span-height (span excludes
  // the camera cutout, which is padded out below). Pushed into the page over
  // the JS bridge so the focused field is seated above the keyboard without
  // the WebView itself being resized.
  double _kbShare = 0;
  double _kbSpanPx = -1;
  double _kbInsetLogical = 0;

  // [FORGE] Rotate the MethodChannel name per project. Keep in
  // sync with MainActivity.kt → `channelName`.
  static const MethodChannel _uploadChannel = MethodChannel('ember/pick');

  // Native IME height feed. MainActivity reads the real WindowInsets.ime()
  // and pushes the height (dp ≈ CSS px) — reliable in landscape, unlike
  // Flutter's viewInsets under a fullscreen IME.
  static const MethodChannel _imeChannel = MethodChannel('ember/ime');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _imeChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'insets' && mounted) {
        final Map<Object?, Object?> m =
            call.arguments as Map<Object?, Object?>;
        final EdgeInsets cut = EdgeInsets.only(
          left: (m['cutL'] as num?)?.toDouble() ?? 0,
          top: (m['cutT'] as num?)?.toDouble() ?? 0,
          right: (m['cutR'] as num?)?.toDouble() ?? 0,
          bottom: (m['cutB'] as num?)?.toDouble() ?? 0,
        );
        // Only the camera-cutout side insets are taken from native (they
        // exclude the nav bar). The keyboard is handled entirely by Dart
        // measuring view.viewInsets.bottom and pushing a share to the page.
        if (cut != _cutout) {
          setState(() => _cutout = cut);
          // The visible span used to compute the keyboard share depends on
          // the cutout — fold the new value in on the next frame.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _measureKeyboard());
        }
      }
      return null;
    });
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _buildController();

    widget.alerts.onIncomingUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    // Debounce connectivity drops — a VPN reconnect or a brief cell
    // switch produces a burst of `none` events that must not fire
    // the offline stage. Only sustained drops route out.
    _connSub = PulseProbe().statusStream.listen((List<ConnectivityResult> r) {
      final bool allNone =
          r.isNotEmpty && r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: RelayConfig.reachDropDebounceMs),
        _showOffline,
      );
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  @override
  void didChangeMetrics() {
    _measureKeyboard();
  }

  FlutterView? _flutterView() {
    if (mounted) {
      final FlutterView? local = View.maybeOf(context);
      if (local != null) return local;
    }
    final Iterable<FlutterView> views =
        WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? null : views.first;
  }

  // Recomputes the keyboard occupancy fraction against the visible span
  // (physical height minus the camera cutout, in device pixels) and pushes
  // it to the page when it actually moves. The WebView itself is not
  // resized — the page seats its own focused field via the JS bridge.
  void _measureKeyboard() {
    final FlutterView? view = _flutterView();
    if (view == null) return;
    final double ratio = view.devicePixelRatio;
    if (ratio <= 0) return;

    final double cutoutPx = (_cutout.top + _cutout.bottom) * ratio;
    final double spanPx = view.physicalSize.height - cutoutPx;
    if (spanPx <= 0) return;

    final double insetLogical = view.viewInsets.bottom / ratio;
    final bool insetMoved = (insetLogical - _kbInsetLogical).abs() >= 1;
    final bool spanMoved = (spanPx - _kbSpanPx).abs() >= 1;
    if (!insetMoved && !spanMoved) return;

    _kbInsetLogical = insetLogical;
    _kbSpanPx = spanPx;

    final double next = (insetLogical * ratio / spanPx).clamp(0.0, 1.0);
    if ((next - _kbShare).abs() < 0.0001) return;
    _kbShare = next;
    unawaited(WebScripts.setKeyboardShare(_web, _kbShare));
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(DeviceSignature.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) async {
          if (mounted) setState(() => _spinner = false);
          _retryCounter = 0;
          await WebScripts.installAll(_web);
          // If the keyboard was already up when the page settled (SPA nav
          // after the field was focused), the fresh document has no idea
          // how much room the keyboard is stealing — re-cast the share.
          if (_kbShare > 0) {
            unawaited(WebScripts.setKeyboardShare(_web, _kbShare));
          }
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool isLoop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (isLoop &&
        _lastMainFrame != null &&
        _retryCounter < RelayConfig.redirectLoopRetries) {
      _retryCounter++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's native error page immediately so the
    // Android chrome robot never leaks visually.
    if (mounted) setState(() => _spinner = true);

    final bool isConnectivity = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (isConnectivity) {
      _showOffline();
    } else {
      _guardOffline();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
    };
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _openExternally(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    controller.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool online = await PulseProbe().canDialOut();
    if (online) return;
    _showOffline();
  }

  void _showOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => PortalStage(
            url: current,
            keystore: widget.keystore,
            alerts: widget.alerts,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _imeChannel.setMethodCallHandler(null);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    widget.alerts.onIncomingUrl = null;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        // The window never moves for the keyboard: on API 30+ the activity
        // pins SOFT_INPUT_ADJUST_NOTHING and here we strip the bottom
        // viewInset from the subtree, so the WebView keeps its full size.
        // The Dart side still reads view.viewInsets.bottom to know the
        // keyboard height and pushes a share to the page over the JS bridge.
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Camera-cutout side padding only (from native displayCutout,
            // excludes the nav bar). No bottom keyboard inset reaches the
            // WebView — the page seats its own focused field.
            Padding(
              padding: _cutout,
              child: MediaQuery(
                data: mq
                    .removeViewInsets(removeBottom: true)
                    .copyWith(
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                    ),
                child: WebViewWidget(controller: _web),
              ),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF63BEF8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
