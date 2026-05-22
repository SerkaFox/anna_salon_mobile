class ApiRecord {
  ApiRecord(this.data);

  final Map<String, dynamic> data;

  String? valueAsText(String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    return value.toString();
  }

  Iterable<MapEntry<String, dynamic>> get displayEntries {
    return data.entries.where((entry) => entry.value != null);
  }
}

class ApiCollection {
  ApiCollection(this.items, {this.raw});

  final List<ApiRecord> items;
  final dynamic raw;

  factory ApiCollection.fromJson(dynamic json) {
    final list = _extractList(json);
    return ApiCollection(
      list.whereType<Map>().map((item) {
        return ApiRecord(Map<String, dynamic>.from(item));
      }).toList(),
      raw: json,
    );
  }

  static List<dynamic> _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map<String, dynamic>) {
      for (final key in const [
        'results',
        'data',
        'items',
        'objects',
        'bookings',
        'reservations',
        'appointments',
      ]) {
        final value = json[key];
        if (value is List) return value;
      }
    }
    return const [];
  }
}

class ApiDocument {
  ApiDocument(this.data);

  final Map<String, dynamic> data;

  factory ApiDocument.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) return ApiDocument(json);
    return ApiDocument({'value': json});
  }
}
