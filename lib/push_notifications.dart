import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api/anna_api.dart';

class PushBookingEvent {
  const PushBookingEvent({
    required this.bookingId,
    required this.date,
    required this.opened,
    this.title = '',
    this.body = '',
  });

  final String bookingId;
  final DateTime date;
  final bool opened;
  final String title;
  final String body;
}

class PushNotifications {
  PushNotifications._();

  static const _apiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');

  static final _events = StreamController<PushBookingEvent>.broadcast();
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _initialized = false;
  static PushBookingEvent? _initialEvent;

  static Stream<PushBookingEvent> get events => _events.stream;
  static PushBookingEvent? takeInitialEvent() {
    final event = _initialEvent;
    _initialEvent = null;
    return event;
  }

  static bool get _hasDartConfiguration =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _projectId.isNotEmpty &&
      _senderId.isNotEmpty;
  static bool get isConfigured => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (_hasDartConfiguration) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: _apiKey,
            appId: _appId,
            messagingSenderId: _senderId,
            projectId: _projectId,
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    } on Object {
      return;
    }
    _initialized = true;

    FirebaseMessaging.onMessage.listen(
      (message) => _emitBooking(message, opened: false),
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _emitBooking(message, opened: true),
    );
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _initialEvent = _bookingEvent(initialMessage, opened: true);
    }
  }

  static Future<void> activate(AnnaApi api, String languageCode) async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await api.registerPushDevice(
          registrationToken: token,
          locale: languageCode,
        );
      }
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        unawaited(
          api.registerPushDevice(
            registrationToken: newToken,
            locale: languageCode,
          ),
        );
      });
    } on Object {
      // Push must never prevent login or normal app use.
    }
  }

  static Future<void> deactivate(AnnaApi api) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty && api.hasCredentials) {
        await api.unregisterPushDevice(token);
      }
    } on Object {
      // Logout must still work if Firebase or the network is unavailable.
    }
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  static void _emitBooking(RemoteMessage message, {required bool opened}) {
    final event = _bookingEvent(message, opened: opened);
    if (event != null) _events.add(event);
  }

  static PushBookingEvent? _bookingEvent(
    RemoteMessage message, {
    required bool opened,
  }) {
    if (message.data['type'] != 'new_booking') return null;
    final bookingId = message.data['booking_id'];
    final date = DateTime.tryParse(message.data['booking_date'] ?? '');
    if (bookingId == null || bookingId.isEmpty || date == null) return null;
    return PushBookingEvent(
      bookingId: bookingId,
      date: date,
      opened: opened,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
    );
  }
}
