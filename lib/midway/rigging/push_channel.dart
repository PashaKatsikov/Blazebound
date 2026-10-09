import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'keybox.dart';
import 'net_agent.dart';
import '../vault/native_vault.dart';
import '../vault/vault_blobs.dart';

// ============================================================
// PUSH CHANNEL — Firebase Messaging + local notifications
// ============================================================
// A cold-start push tap (app killed) is read once via
// getInitialMessage and kept only in memory for this process.
// The URL is never written to disk: the next launch without a
// tap follows the config URL, or the last cached one. Warm taps
// deliver via [onIncomingUrl] and are also not persisted.
//
// [FORGE] The Android notification channel id must match the
// `default_notification_channel_id` in AndroidManifest.xml. Rotate
// per project — a shared id creates an obvious cross-app cluster.
//
// The channel identity, description and small-icon name are no longer Dart
// literals: on Android they are decrypted per call from the native vault
// (see lib/midway/vault). The manifest still carries the channel id in the
// clear (Android requires a resource value there) — the id below MUST equal
// it. Off Android the generic fallbacks keep QA functional.
// ============================================================

String _vaultOr(int key, String fallback) {
  final String v = NativeVault.isSupported ? NativeVault.get(key) : '';
  return v.isEmpty ? fallback : v;
}

// Must match AndroidManifest's default_notification_channel_id.
String get _channelId => _vaultOr(kVaultPushChannelId, 'app_alerts');
// User-visible in Android system settings.
String get _channelName => _vaultOr(kVaultPushChannelName, 'Notifications');
String get _channelDesc => _vaultOr(kVaultPushChannelDesc, '');
String get _smallIcon => _vaultOr(kVaultPushSmallIcon, '@drawable/ic_notification');

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // OS renders the notification; the tap is handled on resume/boot.
}

class PushChannel {
  PushChannel(this._keystore);

  final KeyBox _keystore;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _token;
  bool _ready = false;

  /// URL from the notification that started this process. Never stored.
  String? _launchUrl;

  /// Warm-tap URL delivery — the WebView should load this directly.
  void Function(String url)? onIncomingUrl;

  /// FCM rotated the token. Coordinator re-POSTs the verdict so the
  /// backend can target this device.
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// One-shot read of the cold-start notification URL. Later boots
  /// in this process, and every later process, see null.
  String? takeLaunchUrl() {
    final String? url = _launchUrl;
    _launchUrl = null;
    return url;
  }

  Future<void> boot() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _setupLocal();

      _token = await _messaging!.getToken();
      _messaging!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenChanged?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _messaging!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet — push stays dormant.
    }
  }

  Future<void> _setupLocal() async {
    final AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onIncomingUrl?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    }
  }

  /// System permission prompt. Records an OS-denied flag so the
  /// invite stage stops reappearing after a hard "no".
  Future<bool> askPermission() async {
    if (_messaging == null) return false;
    final NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _keystore.markPermissionGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _keystore.markPermissionBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    final String channelId = _channelId;
    final String channelName = _channelName;
    final String icon = _smallIcon;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: icon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: icon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      _launchUrl = url;
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      onIncomingUrl?.call(url);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final dynamic res = await netAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
