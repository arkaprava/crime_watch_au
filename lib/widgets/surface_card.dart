import 'package:flutter/material.dart';

import 'glass_surface.dart';

/// Frosted glass card used for floating map overlays.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.margin,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: padding,
      margin: margin,
      elevated: elevated,
      child: child,
    );
  }
}
