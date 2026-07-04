/// Pure domain model. The `Uncategorized` system category has id == 'uncategorized'.
class Category {
  final String id;
  final String name;

  /// Lowercased + trimmed — unique key for deduplication and #tag filtering.
  final String nameNormalized;

  /// True only for the seeded 'Uncategorized' category — cannot be deleted or renamed.
  final bool isSystem;

  const Category({
    required this.id,
    required this.name,
    required this.nameNormalized,
    this.isSystem = false,
  });

  static const uncategorized = Category(
    id: 'uncategorized',
    name: 'Uncategorized',
    nameNormalized: 'uncategorized',
    isSystem: true,
  );

  /// Normalize a user-provided category name for dedup comparison.
  static String normalize(String name) => name.trim().toLowerCase();

  Category copyWith({String? name, String? nameNormalized}) {
    return Category(
      id: id,
      name: name ?? this.name,
      nameNormalized: nameNormalized ?? this.nameNormalized,
      isSystem: isSystem,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category(id: $id, name: $name)';
}
