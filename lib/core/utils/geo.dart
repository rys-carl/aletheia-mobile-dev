import 'dart:math' as math;

import 'package:aletheia_dev/core/models/place_choice.dart';

/// Straight-line distance between two coordinates, in meters.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(a));
}

/// Two places count as the same spot if they have the same name (ignoring
/// capitals) and are within 200 meters of each other.
bool isSameSpot(PlaceChoice a, PlaceChoice b) {
  final sameName = a.name.trim().toLowerCase() == b.name.trim().toLowerCase();
  return sameName && distanceMeters(a.lat, a.lng, b.lat, b.lng) <= 200;
}
