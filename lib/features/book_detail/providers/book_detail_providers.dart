import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';

final bookDetailProvider = StreamProvider.autoDispose.family<Book?, String>((
  ref,
  id,
) {
  return ref.watch(bookRepositoryProvider).watchBook(id);
});
