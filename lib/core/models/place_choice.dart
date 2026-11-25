/// A location chosen for a memory. If [id] is set, it is an existing row in
/// the `places` table; otherwise it is new and will be created on save.
class PlaceChoice {
  const PlaceChoice({
    this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String? id;
  final String name;
  final double lat;
  final double lng;

  factory PlaceChoice.fromMap(Map<String, dynamic> m) => PlaceChoice(
        id: m['id'] as String?,
        name: m['name'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
      );
}
