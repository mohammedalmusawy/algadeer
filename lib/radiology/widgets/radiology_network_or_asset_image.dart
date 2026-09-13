import 'package:flutter/material.dart';

import '../../branding/ghadeer_brand_mark.dart';
import '../radiology_default_images.dart';

class RadiologyNetworkOrAssetImage extends StatelessWidget {
  const RadiologyNetworkOrAssetImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });

  final String path;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final p = GhadeerBranding.normalizeEntityImageUrl(path.trim());
    if (p.isEmpty) {
      return errorBuilder?.call(context, 'empty', null) ??
          const SizedBox.shrink();
    }
    if (RadiologyDefaultImages.isAssetPath(p) ||
        GhadeerBranding.isAssetPath(p)) {
      return Image.asset(
        p,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        errorBuilder: errorBuilder,
      );
    }
    return Image.network(
      p,
      fit: fit,
      alignment: alignment,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
  }
}

ImageProvider? radiologyImageProvider(String path) {
  return ghadeerResolvedImageProvider(path);
}
