import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/api_record.dart';

class AnnaApiException implements Exception {
  AnnaApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() => message;
}

class AnnaApi {
  AnnaApi({
    http.Client? client,
    FlutterSecureStorage? storage,
    this.baseUrl = 'https://brimoon.es/api/v1/',
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String baseUrl;

  static const _usernameKey = 'anna_dev_basic_username';
  static const _passwordKey = 'anna_dev_basic_password';

  String? _username;
  String? _password;

  bool get hasCredentials => _username != null && _password != null;

  Future<bool> restoreDevCredentials() async {
    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null || password == null) return false;
    _username = username;
    _password = password;
    try {
      await me();
      return true;
    } on AnnaApiException {
      await clearDevCredentials();
      return false;
    }
  }

  Future<ApiDocument> loginWithBasicAuth({
    required String username,
    required String password,
    required bool storeForDev,
  }) async {
    _username = username;
    _password = password;
    try {
      final profile = await me();
      if (storeForDev) {
        await _storage.write(key: _usernameKey, value: username);
        await _storage.write(key: _passwordKey, value: password);
      } else {
        await clearStoredOnly();
      }
      return profile;
    } on TimeoutException {
      _username = null;
      _password = null;
      throw AnnaApiException('No se pudo conectar con el servidor.');
    } on AnnaApiException {
      _username = null;
      _password = null;
      rethrow;
    }
  }

  Future<void> clearDevCredentials() async {
    _username = null;
    _password = null;
    await clearStoredOnly();
  }

  Future<void> clearStoredOnly() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }

  Future<ApiDocument> me() async {
    return ApiDocument.fromJson(await _get('me/'));
  }

  Future<ApiDocument> updateMe(Map<String, dynamic> payload) async {
    final document = ApiDocument.fromJson(await _patch('me/', payload));
    final newPassword = payload['new_password'];
    if (newPassword is String && newPassword.isNotEmpty) {
      _password = newPassword;
      final storedUsername = await _storage.read(key: _usernameKey);
      if (storedUsername != null) {
        await _storage.write(key: _passwordKey, value: newPassword);
      }
    }
    return document;
  }

  Future<ApiCollection> calendarDay(DateTime date) async {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    return ApiCollection.fromJson(
      await _get('calendar/day/', query: {'date': formatted}),
    );
  }

  Future<ApiCollection> clients() async {
    return ApiCollection.fromJson(await _get('clients/'));
  }

  Future<ApiDocument> clientDetail(Object clientId) async {
    return ApiDocument.fromJson(await _get('clients/$clientId/'));
  }

  Future<ApiCollection> clientRewards(Object clientId) async {
    return ApiCollection.fromJson(await _get('clients/$clientId/rewards/'));
  }

  Future<ApiDocument> createClient(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('clients/', payload));
  }

  Future<ApiDocument> updateClient(
    Object clientId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(await _patch('clients/$clientId/', payload));
  }

  Future<void> deleteClient(Object clientId) async {
    await _delete('clients/$clientId/');
  }

  Future<ApiDocument> uploadClientAvatar({
    required Object clientId,
    required String imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('clients/$clientId/avatar/'),
    );
    request.headers.addAll(_headers());
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return ApiDocument.fromJson(_decode(response));
  }

  Future<ApiCollection> services() async {
    return ApiCollection.fromJson(await _get('services/'));
  }

  Future<ApiCollection> employees() async {
    return ApiCollection.fromJson(await _get('employees/'));
  }

  Future<ApiDocument> employeeDetail(
    Object employeeId, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, String>{};
    if (dateFrom != null) {
      query['date_from'] = DateFormat('yyyy-MM-dd').format(dateFrom);
    }
    if (dateTo != null) {
      query['date_to'] = DateFormat('yyyy-MM-dd').format(dateTo);
    }
    return ApiDocument.fromJson(
      await _get(
        'employees/$employeeId/',
        query: query.isEmpty ? null : query,
      ),
    );
  }

  Future<ApiDocument> createEmployee(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('employees/', payload));
  }

  Future<ApiDocument> updateEmployee(
    Object employeeId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
        await _patch('employees/$employeeId/', payload));
  }

  Future<ApiDocument> employeeSchedule(Object employeeId) async {
    return ApiDocument.fromJson(await _get('employees/$employeeId/schedule/'));
  }

  Future<ApiDocument> updateEmployeeSchedule(
    Object employeeId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _patch('employees/$employeeId/schedule/', payload),
    );
  }

  Future<void> deleteEmployee(Object employeeId) async {
    await _delete('employees/$employeeId/');
  }

  Future<ApiDocument> bookingDetail(Object bookingId) async {
    return ApiDocument.fromJson(await _get('bookings/$bookingId/'));
  }

  Future<ApiDocument> createService(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('services/', payload));
  }

  Future<ApiDocument> updateService(
    Object serviceId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(await _patch('services/$serviceId/', payload));
  }

  Future<void> deleteService(Object serviceId) async {
    await _delete('services/$serviceId/');
  }

  Future<ApiCollection> clientRewardRules() async {
    return ApiCollection.fromJson(await _get('client-reward-rules/'));
  }

  Future<ApiDocument> updateClientRewardRule(
    Object ruleId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _patch('client-reward-rules/$ruleId/', payload),
    );
  }

  Future<ApiDocument> createZone(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('zones/', payload));
  }

  Future<ApiDocument> updateZone(
    Object zoneId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(await _patch('zones/$zoneId/', payload));
  }

  Future<void> deleteZone(Object zoneId) async {
    await _delete('zones/$zoneId/');
  }

  Future<ApiCollection> zones() async {
    return ApiCollection.fromJson(await _get('zones/'));
  }

  Future<ApiDocument> checkAvailability(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(
      await _post('bookings/check-availability/', payload),
    );
  }

  Future<ApiDocument> availabilitySlots(Map<String, String> query) async {
    return ApiDocument.fromJson(
        await _get('availability/slots/', query: query));
  }

  Future<ApiDocument> createBooking(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('bookings/', payload));
  }

  Future<ApiCollection> bookings({DateTime? date}) async {
    final query = date == null
        ? null
        : <String, String>{'date': DateFormat('yyyy-MM-dd').format(date)};
    return ApiCollection.fromJson(await _get('bookings/', query: query));
  }

  Future<ApiCollection> waitlist() async {
    return ApiCollection.fromJson(await _get('waitlist/'));
  }

  Future<ApiDocument> updateWaitlistStatus(
    Object entryId,
    String status,
  ) async {
    return ApiDocument.fromJson(
      await _patch('waitlist/$entryId/', {'status': status}),
    );
  }

  Future<ApiDocument> updateBooking(
    Object bookingId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(await _patch('bookings/$bookingId/', payload));
  }

  Future<ApiDocument> uploadBookingPhoto({
    required Object bookingId,
    required String imagePath,
    required String photoType,
    bool isVisibleToClient = false,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('bookings/$bookingId/photos/'),
    );
    request.headers.addAll(_headers());
    request.fields['photo_type'] = photoType;
    request.fields['is_visible_to_client'] =
        isVisibleToClient ? 'true' : 'false';
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return ApiDocument.fromJson(_decode(response));
  }

  Future<ApiDocument> updateBookingPhotoVisibility({
    required Object photoId,
    required bool isVisibleToClient,
  }) async {
    return ApiDocument.fromJson(
      await _patch('photos/$photoId/', {
        'is_visible_to_client': isVisibleToClient,
      }),
    );
  }

  Future<ApiDocument> updateBookingStatus(
    Object bookingId,
    String status,
  ) async {
    return ApiDocument.fromJson(
      await _post('bookings/$bookingId/status/', {'status': status}),
    );
  }

  Future<ApiDocument> rescheduleBooking(
    Object bookingId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('bookings/$bookingId/reschedule/', payload),
    );
  }

  Future<ApiDocument> bookingStripeCheckout(Object bookingId) async {
    return ApiDocument.fromJson(
      await _post('bookings/$bookingId/stripe-checkout/', const {}),
    );
  }

  Future<ApiDocument> editBookingService(
    Object bookingId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('bookings/$bookingId/edit-services/', payload),
    );
  }

  Future<ApiDocument> quickBookingPayment(
    Object bookingId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('bookings/$bookingId/quick-payment/', payload),
    );
  }

  Future<ApiDocument> createCashDocument(
    Object bookingId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('bookings/$bookingId/cash-document/', payload),
    );
  }

  Future<ApiDocument> cashbox({
    DateTime? date,
    String? method,
    String? entryType,
  }) async {
    final query = <String, String>{};
    if (date != null) {
      query['date'] = DateFormat('yyyy-MM-dd').format(date);
    }
    if (method != null && method.isNotEmpty) {
      query['method'] = method;
    }
    if (entryType != null && entryType.isNotEmpty) {
      query['entry_type'] = entryType;
    }
    return ApiDocument.fromJson(
      await _get('cashbox/', query: query.isEmpty ? null : query),
    );
  }

  Future<ApiDocument> updateDepositPercent(String value) async {
    return ApiDocument.fromJson(
      await _patch('cashbox/', {'deposit_percent': value}),
    );
  }

  Future<ApiDocument> cashDocumentDetail(Object documentId) async {
    return ApiDocument.fromJson(await _get('cashbox/documents/$documentId/'));
  }

  Future<ApiDocument> addCashDocumentLine(
    Object documentId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('cashbox/documents/$documentId/lines/', payload),
    );
  }

  Future<ApiDocument> addCashDocumentPayment(
    Object documentId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('cashbox/documents/$documentId/payments/', payload),
    );
  }

  Future<ApiDocument> shareCashDocument(
    Object documentId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _post('cashbox/documents/$documentId/share/', payload),
    );
  }

  Future<ApiDocument> closeCashbox(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('cashbox/close/', payload));
  }

  Future<ApiDocument> createTimeBlock(Map<String, dynamic> payload) async {
    return ApiDocument.fromJson(await _post('time-blocks/', payload));
  }

  Future<ApiDocument> updateTimeBlock(
    Object timeBlockId,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _patch('time-blocks/$timeBlockId/', payload),
    );
  }

  Future<void> deleteTimeBlock(Object timeBlockId) async {
    await _delete('time-blocks/$timeBlockId/');
  }

  Future<ApiCollection> notifications() async {
    return ApiCollection.fromJson(await _get('notifications/'));
  }

  Future<ApiDocument> notificationDetail(String kind) async {
    return ApiDocument.fromJson(await _get('notifications/$kind/'));
  }

  Future<ApiDocument> updateNotification(
    String kind,
    Map<String, dynamic> payload,
  ) async {
    return ApiDocument.fromJson(
      await _patch('notifications/$kind/', payload),
    );
  }

  Future<ApiDocument> resetNotification(String kind) async {
    return ApiDocument.fromJson(
      await _post('notifications/$kind/reset/', const {}),
    );
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final response = await _client
        .get(
          _uri(path, query),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(jsonBody: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final response = await _client
        .patch(
          _uri(path),
          headers: _headers(jsonBody: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<dynamic> _delete(String path) async {
    final response = await _client
        .delete(
          _uri(path),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse(baseUrl).resolve(path);
    if (query == null) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (jsonBody) headers['Content-Type'] = 'application/json';
    if (_username != null && _password != null) {
      final token = base64Encode(utf8.encode('$_username:$_password'));
      headers['Authorization'] = 'Basic $token';
    }
    return headers;
  }

  Map<String, String> imageHeaders() => _headers();

  String resolveApiUrl(String path) => _uri(path).toString();

  dynamic _decode(http.Response response) {
    final body = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AnnaApiException(
        'API request failed with HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
        body: body,
      );
    }
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException {
      throw AnnaApiException(
        'API returned a non-JSON response.',
        statusCode: response.statusCode,
        body: body,
      );
    }
  }
}
