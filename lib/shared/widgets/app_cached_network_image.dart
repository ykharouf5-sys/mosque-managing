import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget Function()? errorBuilder;

  const AppCachedNetworkImage({
    super.key,
    required this.url,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 120),
      errorWidget: (_, _, _) => errorBuilder?.call() ?? const SizedBox.shrink(),
    );
  }
}
