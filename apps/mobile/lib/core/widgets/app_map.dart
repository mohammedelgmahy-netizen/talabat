import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/env.dart';

/// علامة على الخريطة
class MapPin {
  const MapPin({required this.point, required this.icon, required this.color, this.rotation});

  final LatLng point;
  final IconData icon;
  final Color color;

  /// زاوية الاتجاه (Heading) بالدرجات لسهم السائق
  final double? rotation;
}

/// خريطة OpenStreetMap موحّدة في التطبيق
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.center,
    this.pins = const [],
    this.polyline,
    this.zoom = 14,
    this.controller,
    this.onTap,
  });

  final LatLng center;
  final List<MapPin> pins;
  final List<LatLng>? polyline;
  final double zoom;
  final MapController? controller;
  final void Function(LatLng point)? onTap;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: onTap == null ? null : (_, p) => onTap!(p),
      ),
      children: [
        TileLayer(urlTemplate: Env.mapTilesUrl, userAgentPackageName: 'com.talabat.delivery'),
        if (polyline != null && polyline!.length > 1)
          PolylineLayer(polylines: [
            Polyline(points: polyline!, strokeWidth: 4, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
          ]),
        MarkerLayer(
          markers: [
            for (final pin in pins)
              Marker(
                point: pin.point,
                width: 44,
                height: 44,
                child: Transform.rotate(
                  angle: (pin.rotation ?? 0) * 3.1415926535 / 180,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                      border: Border.all(color: pin.color, width: 2),
                    ),
                    child: Icon(pin.icon, color: pin.color, size: 24),
                  ),
                ),
              ),
          ],
        ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}
