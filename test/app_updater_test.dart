import 'package:flutter_test/flutter_test.dart';

import 'package:anna_salon_mobile/app_updater.dart';
import 'package:anna_salon_mobile/app_version.dart';

void main() {
  test('update manifest parses version, checksum and localized notes', () {
    final info = AppUpdateInfo.fromJson({
      'version_code': 34,
      'version_name': '0.1.33',
      'apk_url': 'https://brimoon.es/media/app.apk',
      'sha256': List.filled(64, 'A').join(),
      'size_bytes': 12345,
      'required': true,
      'notes_ru': ['Исправление'],
      'notes_es': ['Correccion'],
    });

    expect(info.versionCode, 34);
    expect(info.versionName, '0.1.33');
    expect(info.sha256, List.filled(64, 'a').join());
    expect(info.sizeBytes, 12345);
    expect(info.required, isTrue);
    expect(info.notesRu, ['Исправление']);
  });

  test('version constants match the latest change log entry', () {
    expect(appChangeLog.first.version, appVersionName);
    expect(appChangeLog.first.build, appVersionBuild);
  });
}
