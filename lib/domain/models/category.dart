class Category {
  final String id;
  final String name;
  final String nameNormalized;
  final bool isSystem;

  const Category({
    required this.id,
    required this.name,
    required this.nameNormalized,
    this.isSystem = false,
  });

  static String normalize(String name) => name.trim().toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Category($id, $name)';
}

const kCategories = <Category>[
  Category(id: 'fiction',           name: 'Fiction',           nameNormalized: 'fiction',           isSystem: true),
  Category(id: 'non-fiction',       name: 'Non-Fiction',       nameNormalized: 'non-fiction',       isSystem: true),
  Category(id: 'novel',             name: 'Novel',             nameNormalized: 'novel',             isSystem: true),
  Category(id: 'literature',        name: 'Literature',        nameNormalized: 'literature',        isSystem: true),
  Category(id: 'tragedy',           name: 'Tragedy',           nameNormalized: 'tragedy',           isSystem: true),
  Category(id: 'self-help',         name: 'Self-Help',         nameNormalized: 'self-help',         isSystem: true),
  Category(id: 'drama',             name: 'Drama',             nameNormalized: 'drama',             isSystem: true),
  Category(id: 'mystery',           name: 'Mystery',           nameNormalized: 'mystery',           isSystem: true),
  Category(id: 'thriller',          name: 'Thriller',          nameNormalized: 'thriller',          isSystem: true),
  Category(id: 'romance',           name: 'Romance',           nameNormalized: 'romance',           isSystem: true),
  Category(id: 'fantasy',           name: 'Fantasy',           nameNormalized: 'fantasy',           isSystem: true),
  Category(id: 'sci-fi',            name: 'Sci-Fi',            nameNormalized: 'sci-fi',            isSystem: true),
  Category(id: 'biography',         name: 'Biography',         nameNormalized: 'biography',         isSystem: true),
  Category(id: 'history',           name: 'History',           nameNormalized: 'history',           isSystem: true),
  Category(id: 'poetry',            name: 'Poetry',            nameNormalized: 'poetry',            isSystem: true),
  Category(id: 'horror',            name: 'Horror',            nameNormalized: 'horror',            isSystem: true),
  Category(id: 'adventure',         name: 'Adventure',         nameNormalized: 'adventure',         isSystem: true),
  Category(id: 'contemporary',      name: 'Contemporary',      nameNormalized: 'contemporary',      isSystem: true),
  Category(id: 'philosophical',     name: 'Philosophical',     nameNormalized: 'philosophical',     isSystem: true),
  Category(id: 'classics',          name: 'Classics',          nameNormalized: 'classics',          isSystem: true),
  Category(id: 'family-saga',       name: 'Family Saga',       nameNormalized: 'family-saga',       isSystem: true),
];
