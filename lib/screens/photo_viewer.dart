import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../api/anna_api.dart';
import '../theme/app_theme.dart';
import 'api_cached_image.dart';

class AnnaPhotoViewer extends StatelessWidget {
  const AnnaPhotoViewer._({
    required this.title,
    this.localPath,
    this.networkUrl,
    this.api,
    this.onDelete,
  });

  final String title;
  final String? localPath;
  final String? networkUrl;
  final AnnaApi? api;
  final VoidCallback? onDelete;

  static Future<void> showLocal(
    BuildContext context, {
    required String title,
    required String path,
    VoidCallback? onDelete,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnnaPhotoViewer._(
          title: title,
          localPath: path,
          onDelete: onDelete,
        ),
      ),
    );
  }

  static Future<void> showNetwork(
    BuildContext context, {
    required String title,
    required String url,
    required AnnaApi api,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnnaPhotoViewer._(
          title: title,
          networkUrl: url,
          api: api,
        ),
      ),
    );
  }

  Future<void> _shareLocal() async {
    final path = localPath;
    if (path == null) return;
    await Share.shareXFiles([XFile(path)], text: title);
  }

  @override
  Widget build(BuildContext context) {
    final path = localPath;
    final url = networkUrl;
    final apiClient = api;
    final image = path != null
        ? Image.file(File(path), fit: BoxFit.contain)
        : ApiCachedImage(
            api: apiClient!,
            url: url!,
            fit: BoxFit.contain,
          );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: AnnaColors.text,
        title: Text(title),
        actions: [
          if (path != null)
            IconButton(
              tooltip: 'Enviar',
              onPressed: _shareLocal,
              icon: Icon(Icons.ios_share_outlined),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Quitar',
              onPressed: () {
                onDelete?.call();
                Navigator.of(context).pop();
              },
              icon: Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: image,
          ),
        ),
      ),
    );
  }
}
