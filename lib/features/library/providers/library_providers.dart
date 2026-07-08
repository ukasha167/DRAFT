import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/omnibox_parser.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';

final currentTabProvider = StateProvider<BookStatus>((_) => BookStatus.owned);

final searchTextProvider = StateProvider<String>((_) => '');

final activeCategoryProvider = StateProvider<String?>((_) => null);

final activeBooksProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  final status = ref.watch(currentTabProvider);
  final text = ref.watch(searchTextProvider);
  final catId = ref.watch(activeCategoryProvider);
  final repo = ref.watch(bookRepositoryProvider);

  final query = ParsedQuery(
    text: text.trim().isEmpty ? null : text.trim(),
    categories: catId != null ? [catId] : const [],
  );

  return repo.watchBooks(status: status, query: query);
});

final lastDeletedProvider = StateProvider<({String id, String title})?>(
  (_) => null,
);
