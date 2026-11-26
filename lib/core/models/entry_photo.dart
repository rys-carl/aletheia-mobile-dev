/// One photo belonging to a memory (`media` table row + signed URL).
class EntryPhoto {
  const EntryPhoto({
    required this.id,
    required this.storagePath,
    required this.url,
    required this.sortOrder,
    required this.isCover,
  });

  final String id;
  final String storagePath;
  final String url;
  final int sortOrder;
  final bool isCover;

  EntryPhoto copyWith({
    String? id,
    String? storagePath,
    String? url,
    int? sortOrder,
    bool? isCover,
  }) {
    return EntryPhoto(
      id: id ?? this.id,
      storagePath: storagePath ?? this.storagePath,
      url: url ?? this.url,
      sortOrder: sortOrder ?? this.sortOrder,
      isCover: isCover ?? this.isCover,
    );
  }
}
