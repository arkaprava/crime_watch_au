import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:platform_maps_flutter/platform_maps_flutter.dart';

import '../models/crime_incident.dart';

/// Renders and caches a colored pin bitmap per [CrimeType], since
/// platform_maps_flutter only ships a single default marker icon.
class MarkerIconFactory {
  MarkerIconFactory._();

  static final Map<CrimeType, BitmapDescriptor> _cache = {};

  static BitmapDescriptor? iconFor(CrimeType type) => _cache[type];

  static Future<void> preload() async {
    for (final type in CrimeType.values) {
      if (_cache.containsKey(type)) continue;
      _cache[type] = BitmapDescriptor.fromBytes(await _renderPin(type.color));
    }
  }

  static Future<ui.Image> _rasterize(ui.Picture picture, int size) {
    return picture.toImage(size, size);
  }

  static Future<Uint8List> _renderPin(Color color) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const center = Offset(size / 2, size / 2 - 8);
    const radius = 28.0;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center.translate(0, 4), radius, shadowPaint);

    // Pin tail.
    final tail = Path()
      ..moveTo(center.dx - 12, center.dy + radius - 10)
      ..lineTo(center.dx, size - 6)
      ..lineTo(center.dx + 12, center.dy + radius - 10)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);

    canvas.drawCircle(center, radius, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);

    final image = await _rasterize(recorder.endRecording(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}
