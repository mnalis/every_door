import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class MultiHitMarkerLayer extends StatelessWidget {
  final List<Marker> markers;
  final Function(List<Key>)? onTap;

  MultiHitMarkerLayer({this.markers = const [], this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final rotate = camera.rotation.abs() > 1.0;
    var rotatedMarkers = <Widget>[];
    for (var i = 0; i < markers.length; i++) {
      var marker = markers[i];

      // Decide whether to use cached point or calculate it
      var pxPoint = camera.project(marker.point).round();

      // Resolve real alignment
      const alignment = Alignment.center;
      final left = 0.5 * marker.width * ((marker.alignment ?? alignment).x + 1);
      final top = 0.5 * marker.height * ((marker.alignment ?? alignment).y + 1);
      final right = marker.width - left;
      final bottom = marker.height - top;

      // Cull if out of bounds
      if (!camera.pixelBounds.containsPartialBounds(
        Bounds(
          Point(pxPoint.x + left, pxPoint.y - bottom),
          Point(pxPoint.x - right, pxPoint.y + top),
        ),
      )) continue;

      // Apply map camera to marker position
      final pos = pxPoint - camera.pixelOrigin.round();

      final rotatedChild = rotate
          ? GestureDetector(
              child: Transform.rotate(
                angle: -camera.rotationRad,
                alignment: (marker.alignment ?? alignment) * -1,
                child: marker.child,
              ),
              onTap: () {
                if (marker.key != null && onTap != null) onTap!([marker.key!]);
              },
            )
          : marker.child;

      rotatedMarkers.add(
        Positioned(
          key: marker.key,
          width: marker.width,
          height: marker.height,
          left: pos.x - right,
          top: pos.y - bottom,
          child: rotatedChild,
        ),
      );
    }

    // if (rotate) {
    //   return Stack(children: rotatedMarkers);
    // }
    return MobileLayerTransformer(
      child: GestureDetector(
        child: Stack(
          children: rotatedMarkers,
        ),
        onTapUp: (details) {
          if (rotate) return;
          List<Key> tapped = [];
          for (final m in rotatedMarkers) {
            final key = m.key;
            if (key != null && key is GlobalKey) {
              final renderBox = key.currentContext?.findRenderObject();
              if (renderBox != null && renderBox is RenderBox) {
                Offset topLeftCorner = renderBox.localToGlobal(Offset.zero);
                Size size = renderBox.size;
                Rect rectangle = topLeftCorner & size;
                if (rectangle.contains(details.globalPosition)) {
                  tapped.add(key);
                }
              }
            }
          }
          if (tapped.isNotEmpty && onTap != null) onTap!(tapped);
        },
      ),
    );
  }
}
