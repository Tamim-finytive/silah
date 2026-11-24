import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/api_service.dart';
import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Notification payloads are displayed by Android/iOS while the app is in
  // the background. Only data-only messages need a local notification here,
  // otherwise users would see duplicate notifications.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (message.notification != null) return;

    final title = message.data['title']?.toString();
    final body = message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_silah'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    const channel = AndroidNotificationChannel(
      NotificationService.announcementChannelId,
      'Masjid announcements',
      description: 'Announcements and important masjid updates',
      importance: Importance.high,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await notifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService.announcementChannelId,
          'Masjid announcements',
          channelDescription: 'Announcements and important masjid updates',
          icon: 'ic_stat_silah',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  } catch (error) {
    debugPrint('Unable to process background notification: $error');
  }
}

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<Map<String, dynamic>> _notificationEvents =
      StreamController.broadcast();
  static const _storage = FlutterSecureStorage();
  static const String _fcmKey = 'silah_cached_fcm_token';
  static const String _fcmUserKey = 'silah_cached_fcm_user_id';
  static const String announcementChannelId = 'silah_announcements';

  String? _cachedToken;
  String? _cachedUserId;
  Map<String, dynamic>? _pendingNotificationEvent;
  bool _isInitialized = false;
  bool _permissionCheckedThisRun = false;

  Stream<Map<String, dynamic>> get notificationEvents =>
      _notificationEvents.stream;

  Map<String, dynamic>? takePendingNotificationEvent() {
    final event = _pendingNotificationEvent;
    _pendingNotificationEvent = null;
    return event;
  }

  void _publishNotificationEvent(Map<String, dynamic> event) {
    if (_notificationEvents.hasListener) {
      _notificationEvents.add(event);
    } else {
      _pendingNotificationEvent = event;
    }
  }

  Map<String, dynamic> _messageEvent(RemoteMessage message,
          {required bool opened}) =>
      {
        ...message.data,
        'title': message.notification?.title ?? message.data['title'],
        'body': message.notification?.body ?? message.data['body'],
        'opened': opened,
      };

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          announcementChannelId,
          'Masjid announcements',
          channelDescription: 'Announcements and important masjid updates',
          icon: 'ic_stat_silah',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(_messageEvent(message, opened: true)),
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize local notifications
      const androidInit = AndroidInitializationSettings('ic_stat_silah');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final event = jsonDecode(payload) as Map<String, dynamic>;
            _publishNotificationEvent({...event, 'opened': true});
          } catch (_) {
            debugPrint('Unable to open notification payload');
          }
        },
      );

      // Keep this ID in sync with FirebaseService so remote and local notices
      // use the same Android notification channel.
      const channel = AndroidNotificationChannel(
        announcementChannelId,
        'Masjid announcements',
        description: 'Announcements and important masjid updates',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 2. Set background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Foreground messages are surfaced locally and refresh DB-backed UI.
      FirebaseMessaging.onMessage.listen((message) async {
        _publishNotificationEvent(_messageEvent(message, opened: false));
        try {
          await _showForegroundNotification(message);
        } catch (e) {
          debugPrint('Unable to show foreground notification: $e');
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _publishNotificationEvent(_messageEvent(message, opened: true));
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _publishNotificationEvent(_messageEvent(initialMessage, opened: true));
      }

      // 4. Token refresh listener (only fires if Firebase rotates token automatically)
      _fcm.onTokenRefresh.listen((newToken) async {
        final currentUserId =
            ApiService.instance.currentUser?['id']?.toString();
        await _cacheAndRegisterToken(newToken, currentUserId);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> _cacheAndRegisterToken(String token, String? userId) async {
    _cachedToken = token;
    await _storage.write(key: _fcmKey, value: token);
    if (userId == null || userId.isEmpty) {
      // A rotated token must be linked again after the next authenticated login.
      _cachedUserId = null;
      await _storage.delete(key: _fcmUserKey);
      return;
    }

    final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
    final registered =
        await ApiService.instance.updateDeviceToken(token, platform: platform);
    if (registered) {
      _cachedUserId = userId;
      await _storage.write(key: _fcmUserKey, value: userId);
    } else {
      // Leave the token cached but retry backend registration on the next login.
      _cachedUserId = null;
      await _storage.delete(key: _fcmUserKey);
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_permissionCheckedThisRun) return;
    _permissionCheckedThisRun = true;
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      'FCM notification authorization: ${settings.authorizationStatus}',
    );
    if (Platform.isAndroid) {
      final granted = await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      debugPrint('Android notifications allowed: $granted');
    }
  }

  /// Reuses existing already-generated FCM token from memory or persistent storage.
  /// Does NOT regenerate every time. Only requests fresh token from Firebase if no token exists yet.
  Future<String?> configureAfterLogin() async {
    try {
      await initialize();

      final currentUserId = ApiService.instance.currentUser?['id']?.toString();

      if (currentUserId == null) return _cachedToken;
      // Ask/check permission even when an existing Firebase token is reused.
      // Cached-token users previously returned before reaching the permission flow.
      await _requestNotificationPermission();

      // 1. Reuse the in-memory token only after backend registration succeeded.
      if (_cachedToken != null &&
          _cachedToken!.isNotEmpty &&
          _cachedUserId == currentUserId) {
        return _cachedToken;
      }

      // 2. Reuse the secure-storage token; only relink when the signed-in user changes.
      final storedToken = await _storage.read(key: _fcmKey);
      final storedUserId = await _storage.read(key: _fcmUserKey);

      if (storedToken != null && storedToken.isNotEmpty) {
        _cachedToken = storedToken;
        _cachedUserId = storedUserId;

        if (storedUserId == currentUserId) {
          return storedToken;
        }

        final platform = Platform.isIOS ? 'IOS' : 'ANDROID';
        final registered = await ApiService.instance
            .updateDeviceToken(storedToken, platform: platform);
        if (registered) {
          await _storage.write(key: _fcmUserKey, value: currentUserId);
          _cachedUserId = currentUserId;
        }
        return storedToken;
      }

      // 3. Ask permission and ask Firebase for its current token only when no
      // reusable device token is stored. getToken returns Firebase's current
      // token; it does not mint a new token on each sign-in.
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _cacheAndRegisterToken(token, currentUserId);
        return token;
      }
    } catch (e) {
      debugPrint('FCM configuration error: $e');
    }
    return _cachedToken;
  }

  /// Trigger immediate prayer alarm and alert notification on device
  Future<void> triggerPrayerAlarm(
      {required String prayerName, required String time}) async {
    await initialize();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'silah_adhan_alarm',
      'Prayer Alarms & Adhan Alerts',
      channelDescription:
          'Audible prayer alarms and reminders for Adhan and Jamaah',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      '🕌 $prayerName Adhan Alarm',
      'It is time for $prayerName prayer ($time). Prepare for congregation at your Masjid!',
      details,
    );
  }
}
