/// An album that groups memories together.
class AlbumChoice {
  const AlbumChoice({
    required this.id,
    required this.title,
    this.description,
    this.coverPath,
    this.coverUrl,
    this.entryCount = 0,
  });

  final String id;
  final String title;
  final String? description;
  final String? coverPath;
  final String? coverUrl;
  final int entryCount;

  factory AlbumChoice.fromMap(Map<String, dynamic> m) => AlbumChoice(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        coverPath: m['cover_path'] as String?,
        coverUrl: m['cover_url'] as String?,
        entryCount: (m['entry_count'] as int?) ?? 0,
      );

  AlbumChoice copyWith({
    String? title,
    String? description,
    String? coverPath,
    String? coverUrl,
    int? entryCount,
  }) =>
      AlbumChoice(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        coverPath: coverPath ?? this.coverPath,
        coverUrl: coverUrl ?? this.coverUrl,
        entryCount: entryCount ?? this.entryCount,
      );
}
