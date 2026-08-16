import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/anna_api.dart';
import '../theme/app_theme.dart';

class ApiCachedImage extends StatelessWidget {
  const ApiCachedImage({
    required this.api,
    required this.url,
    required this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  final AnnaApi api;
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  static Future<void> evict(AnnaApi api, String url) {
    final resolved = api.resolveApiUrl(url);
    return CachedNetworkImage.evictFromCache(resolved, cacheKey: resolved);
  }

  @override
  Widget build(BuildContext context) {
    final resolved = api.resolveApiUrl(url);
    return CachedNetworkImage(
      imageUrl: resolved,
      cacheKey: resolved,
      httpHeaders: api.imageHeaders(),
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: placeholder == null
          ? null
          : (context, url) => SizedBox(
                width: width,
                height: height,
                child: placeholder,
              ),
      errorWidget: errorWidget == null
          ? (context, url, error) => Icon(
                Icons.broken_image_outlined,
                color: AnnaColors.muted,
              )
          : (context, url, error) => errorWidget!,
    );
  }
}
