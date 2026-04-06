import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String kNotificationChannelId = 'damascus_projects_push';
const String kNotificationChannelName = 'Damascus Projects';
const String kNotificationChannelDescription =
    'Push notifications from Damascus Projects';

Uri? _pendingNotificationTap;
final StreamController<Uri?> _notificationTapController =
    StreamController<Uri?>.broadcast();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationNavigationBus {
  NotificationNavigationBus._();

  static final NotificationNavigationBus instance =
      NotificationNavigationBus._();

  Stream<Uri?> get stream => _notificationTapController.stream;

  Uri? consumePendingTap() {
    final uri = _pendingNotificationTap;
    _pendingNotificationTap = null;
    return uri;
  }

  void dispatch(Uri? uri) {
    _pendingNotificationTap = uri;
    if (!_notificationTapController.isClosed) {
      _notificationTapController.add(uri);
    }
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final AndroidNotificationChannel _androidChannel = const AndroidNotificationChannel(
    kNotificationChannelId,
    kNotificationChannelName,
    description: kNotificationChannelDescription,
    importance: Importance.max,
  );

  void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    try {
      await FirebaseMessaging.instance.subscribeToTopic("general_broadcast");
      if (kDebugMode) {
        debugPrint("Subscribed to topic: general_broadcast");
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Topic subscription failed: $e");
      }
    }

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      ),
      onDidReceiveNotificationResponse: (response) {
        _dispatchPayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);

    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleRemoteMessageTap(message);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageTap(initialMessage);
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (kDebugMode) {
      debugPrint('FCM token: $token');
    }
  }

  Uri? extractUrl(RemoteMessage message) {
    final data = message.data;
    final candidate = data['url'] ?? data['link'] ?? data['deep_link'];
    if (candidate == null) {
      return null;
    }
    return Uri.tryParse(candidate.toString());
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    NotificationNavigationBus.instance.dispatch(extractUrl(message));
  }

  void _dispatchPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      NotificationNavigationBus.instance.dispatch(null);
      return;
    }

    NotificationNavigationBus.instance.dispatch(Uri.tryParse(payload));
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'Damascus Projects';
    final body = notification?.body ?? message.data['body']?.toString();
    final url = extractUrl(message)?.toString();

    if (title.isEmpty && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: url,
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  PushNotificationService.instance
      ._dispatchPayload(notificationResponse.payload);
}
