import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

class PushActivationResult {
  const PushActivationResult({
    required this.configured,
    required this.permissionGranted,
    required this.registered,
    this.error,
  });

  final bool configured;
  final bool permissionGranted;
  final bool registered;
  final String? error;

  bool get active => configured && permissionGranted && registered;
}

class PushNotifications {
  PushNotifications._();

  static const _storage = FlutterSecureStorage();
  static const _disabledKey = 'push_notifications_disabled';

  static const _apiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');

  static final _events = StreamController<PushBookingEvent>.broadcast();
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static bool _initialized = false;
  static bool _registered = false;
  static String? _initializationError;
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
    } on Object catch (error) {
      _initializationError = error.toString();
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

  static Future<PushActivationResult> status() async {
    if (!_initialized) {
      return PushActivationResult(
        configured: false,
        permissionGranted: false,
        registered: false,
        error: _initializationError,
      );
    }
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      return PushActivationResult(
        configured: true,
        permissionGranted: granted,
        registered: _registered,
      );
    } on Object catch (error) {
      return PushActivationResult(
        configured: true,
        permissionGranted: false,
        registered: false,
        error: error.toString(),
      );
    }
  }

  static Future<PushActivationResult> activate(
    AnnaApi api,
    String languageCode, {
    bool manual = false,
  }) async {
    if (!_initialized) await initialize();
    if (!_initialized) return status();
    try {
      if (manual) {
        await _storage.delete(key: _disabledKey);
      } else if (await _storage.read(key: _disabledKey) == 'true') {
        return status();
      }
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        return const PushActivationResult(
          configured: true,
          permissionGranted: false,
          registered: false,
        );
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        return const PushActivationResult(
          configured: true,
          permissionGranted: true,
          registered: false,
          error: 'Firebase did not return a device token.',
        );
      }
      await api.registerPushDevice(
        registrationToken: token,
        locale: languageCode,
      );
      _registered = true;
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen((newToken) {
        unawaited(
          api.registerPushDevice(
            registrationToken: newToken,
            locale: languageCode,
          ),
        );
      });
      return const PushActivationResult(
        configured: true,
        permissionGranted: true,
        registered: true,
      );
    } on Object catch (error) {
      return PushActivationResult(
        configured: true,
        permissionGranted: false,
        registered: false,
        error: error.toString(),
      );
    }
  }

  static Future<void> deactivate(
    AnnaApi api, {
    bool rememberDisabled = false,
  }) async {
    if (rememberDisabled) {
      await _storage.write(key: _disabledKey, value: 'true');
    }
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
    _registered = false;
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
