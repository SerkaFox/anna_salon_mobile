import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'app_version.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.required,
    required this.notesRu,
    required this.notesEs,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String sha256;
  final int sizeBytes;
  final bool required;
  final List<String> notesRu;
  final List<String> notesEs;

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? value) => value is List
        ? value.map((item) => item.toString()).toList()
        : const [];
    return AppUpdateInfo(
      versionCode: int.tryParse(json['version_code']?.toString() ?? '') ?? 0,
      versionName: json['version_name']?.toString() ?? '',
      apkUrl: json['apk_url']?.toString() ?? '',
      sha256: json['sha256']?.toString().toLowerCase() ?? '',
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
      required: json['required'] == true,
      notesRu: strings(json['notes_ru']),
      notesEs: strings(json['notes_es']),
    );
  }
}

class AppUpdater {
  AppUpdater._();

  static const _manifestUrl =
      'https://brimoon.es/api/v1/app-update/?source=android';
  static const _channel = MethodChannel('brimoon/app_updater');

  static Future<void> checkForUpdates(
    BuildContext context, {
    required String languageCode,
    bool manual = false,
  }) async {
    if (!Platform.isAndroid) {
      if (manual && context.mounted) {
        _message(
            context,
            languageCode == 'ru'
                ? 'Обновления APK доступны только на Android.'
                : 'Las actualizaciones APK solo estan disponibles en Android.');
      }
      return;
    }
    final russian = languageCode == 'ru';
    AppUpdateInfo info;
    try {
      info = await fetchManifest();
    } catch (_) {
      if (manual && context.mounted) {
        _message(
          context,
          russian
              ? 'Не удалось проверить обновления.'
              : 'No se pudieron comprobar las actualizaciones.',
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (info.versionCode <= appVersionBuild) {
      if (manual) {
        _message(
          context,
          russian
              ? 'Установлена актуальная версия $appVersionName ($appVersionBuild).'
              : 'La version $appVersionName ($appVersionBuild) esta actualizada.',
        );
      }
      return;
    }
    if (info.apkUrl.isEmpty || info.sha256.length != 64) {
      if (manual) {
        _message(
          context,
          russian
              ? 'Обновление опубликовано не полностью. Попробуйте позже.'
              : 'La actualizacion aun no esta completa. Prueba mas tarde.',
        );
      }
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: !info.required,
      builder: (_) => _UpdateAvailableDialog(
        info: info,
        russian: russian,
      ),
    );
    if (accepted != true || !context.mounted) return;

    final path = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDownloadDialog(info: info, russian: russian),
    );
    if (path == null || !context.mounted) return;

    final canInstall =
        await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    if (!context.mounted) return;
    if (!canInstall) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(
              russian ? 'Разрешение на установку' : 'Permiso para instalar'),
          content: Text(
            russian
                ? 'Один раз разрешите BRIMOON Studio устанавливать обновления. После возврата установка продолжится автоматически.'
                : 'Permite una vez que BRIMOON Studio instale actualizaciones. Al volver, la instalacion continuara automaticamente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(russian ? 'Позже' : 'Mas tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(russian ? 'Открыть настройки' : 'Abrir ajustes'),
            ),
          ],
        ),
      );
      if (openSettings == true) {
        final granted = await _channel
                .invokeMethod<bool>('requestInstallPermission') ??
            false;
        if (!context.mounted) return;
        if (!granted) {
          _message(
            context,
            russian
                ? 'Разрешение не выдано. Установка обновления отменена.'
                : 'No se concedio el permiso. La instalacion se cancelo.',
          );
          return;
        }
        await _startInstallation(context, path, russian);
      }
      return;
    }

    await _startInstallation(context, path, russian);
  }

  static Future<void> _startInstallation(
    BuildContext context,
    String path,
    bool russian,
  ) async {
    try {
      await _channel.invokeMethod<String>('installApk', {'path': path});
      if (context.mounted) {
        _message(
          context,
          russian
              ? 'Установка обновления запущена.'
              : 'Se ha iniciado la instalacion de la actualizacion.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          russian
              ? 'Не удалось запустить установку.'
              : 'No se pudo iniciar la instalacion.',
        );
      }
    }
  }

  static Future<AppUpdateInfo> fetchManifest() async {
    final response = await http.get(
      Uri.parse(_manifestUrl),
      headers: const {'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw HttpException('Update manifest HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('Invalid update manifest');
    return AppUpdateInfo.fromJson(Map<String, dynamic>.from(decoded));
  }

  static Future<String> downloadAndVerify(
    AppUpdateInfo info,
    ValueChanged<double> onProgress,
  ) async {
    final directory = await _channel.invokeMethod<String>('updateDirectory');
    if (directory == null || directory.isEmpty) {
      throw FileSystemException('Update directory is unavailable.');
    }
    final file = File('$directory/brimoon-${info.versionCode}.apk');
    if (await file.exists() && await _matchesHash(file.path, info.sha256)) {
      onProgress(1);
      return file.path;
    }
    if (await file.exists()) await file.delete();

    final client = http.Client();
    IOSink? sink;
    try {
      final request = http.Request('GET', Uri.parse(info.apkUrl));
      request.headers['Cache-Control'] = 'no-cache';
      final response = await client.send(request).timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode != 200) {
        throw HttpException('APK download HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? info.sizeBytes;
      var received = 0;
      await file.parent.create(recursive: true);
      sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0, 1));
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } finally {
      await sink?.close();
      client.close();
    }
    if (info.sizeBytes > 0 && await file.length() != info.sizeBytes) {
      await file.delete();
      throw const FormatException('Downloaded APK size mismatch.');
    }
    if (!await _matchesHash(file.path, info.sha256)) {
      await file.delete();
      throw const FormatException('Downloaded APK checksum mismatch.');
    }
    onProgress(1);
    return file.path;
  }

  static Future<bool> _matchesHash(String path, String expected) async {
    final actual =
        await _channel.invokeMethod<String>('sha256', {'path': path});
    return actual?.toLowerCase() == expected.toLowerCase();
  }

  static void _message(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  const _UpdateAvailableDialog({required this.info, required this.russian});

  final AppUpdateInfo info;
  final bool russian;

  @override
  Widget build(BuildContext context) {
    final notes = russian ? info.notesRu : info.notesEs;
    return AlertDialog(
      title: Text(russian
          ? 'Доступно обновление ${info.versionName}'
          : 'Actualizacion ${info.versionName} disponible'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(russian
                ? 'Установлена версия $appVersionName. Новая версия будет скачана с brimoon.es.'
                : 'Version instalada: $appVersionName. La nueva version se descargara desde brimoon.es.'),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 17),
                      const SizedBox(width: 8),
                      Expanded(child: Text(note)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        if (!info.required)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(russian ? 'Позже' : 'Mas tarde'),
          ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.system_update_alt),
          label:
              Text(russian ? 'Скачать и установить' : 'Descargar e instalar'),
        ),
      ],
    );
  }
}

class _UpdateDownloadDialog extends StatefulWidget {
  const _UpdateDownloadDialog({required this.info, required this.russian});

  final AppUpdateInfo info;
  final bool russian;

  @override
  State<_UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<_UpdateDownloadDialog> {
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() => _error = null);
    try {
      final path = await AppUpdater.downloadAndVerify(
        widget.info,
        (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (mounted) Navigator.pop(context, path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = widget.russian
              ? 'Не удалось скачать или проверить APK.'
              : 'No se pudo descargar o verificar el APK.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.russian ? 'Скачивание обновления' : 'Descargando'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 10),
          Text(_error ?? '${(_progress * 100).round()}%'),
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: _download,
            child: Text(widget.russian ? 'Повторить' : 'Reintentar'),
          ),
      ],
    );
  }
}
