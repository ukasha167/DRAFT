import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/book_lookup_repository.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/category.dart';
import '../providers/add_book_providers.dart';
import '../widgets/book_form_widget.dart';

class AddBookSheet extends ConsumerStatefulWidget {
  const AddBookSheet({super.key});

  @override
  ConsumerState<AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends ConsumerState<AddBookSheet> {
  final _searchCtrl = TextEditingController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 450));

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (value.trim().length < 3) {
      ref.read(addBookProvider.notifier).reset();
      return;
    }
    _debouncer.run(() => ref.read(addBookProvider.notifier).search(value));
  }

  Future<void> _save({
    required String title,
    String? author,
    String? isbn,
    String? summary,
    required List<String> categoryIds,
    String? coverUrl,
    required BookStatus status,
  }) async {
    // Soft duplicate warning — non-blocking.
    final isDupe =
        await ref.read(bookRepositoryProvider).isDuplicate(title, author);
    if (isDupe && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Possible duplicate'),
          content: Text(
            '"$title"${author != null ? ' by $author' : ''} may already be in your library.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add anyway')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    await ref.read(bookRepositoryProvider).addBook(
          title: title,
          status: status,
          author: author,
          isbn: isbn,
          summary: summary,
          coverUrl: coverUrl,
          categoryIds: categoryIds,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addBookProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header + close
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                child: Row(
                  children: [
                    Text(_headerTitle(state),
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    if (state is! AddBookIdle && state is! AddBookSearching)
                      TextButton(
                        onPressed: () =>
                            ref.read(addBookProvider.notifier).reset(),
                        child: const Text('Back'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: switch (state) {
                  AddBookIdle() || AddBookSearching() || AddBookResults() ||
                  AddBookNoResults() || AddBookError() =>
                    _buildSearchPhase(state),
                  AddBookForm(:final prefilled) =>
                    _buildFormPhase(prefilled),
                  AddBookSaving() => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  AddBookDone() => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _headerTitle(AddBookState state) => switch (state) {
        AddBookForm(prefilled: null) => 'Manual entry',
        AddBookForm() => 'Confirm details',
        _ => 'Add book',
      };

  Widget _buildSearchPhase(AddBookState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by title or author…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: state is AddBookSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child:
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: switch (state) {
            AddBookIdle() => _buildIdleHint(),
            AddBookSearching() => const SizedBox.shrink(),
            AddBookResults(:final candidates) =>
              _buildResultsList(candidates),
            AddBookNoResults() => _buildNoResults(),
            AddBookError(:final message) => _buildError(message),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  Widget _buildIdleHint() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded, size: 48, color: AppColors.accent),
          const SizedBox(height: 12),
          Text('Type 3+ characters to search',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Enter manually'),
            onPressed: () =>
                ref.read(addBookProvider.notifier).goManual(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<BookCandidate> candidates) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        ...candidates.map((c) => _CandidateTile(
              candidate: c,
              onTap: () =>
                  ref.read(addBookProvider.notifier).selectCandidate(c),
            )),
        const Divider(height: 24),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('None of these — enter manually'),
            onPressed: () =>
                ref.read(addBookProvider.notifier).goManual(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('No results found'),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => ref.read(addBookProvider.notifier).goManual(),
            child: const Text('Enter manually'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48),
          const SizedBox(height: 12),
          const Text('Search unavailable'),
          const SizedBox(height: 4),
          Text(msg,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => ref.read(addBookProvider.notifier).goManual(),
            child: const Text('Enter manually'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPhase(BookCandidate? prefilled) {
    return BookFormWidget(
      initialTitle: prefilled?.title,
      initialAuthor: prefilled?.author,
      initialIsbn: prefilled?.isbn,
      initialSummary: prefilled?.description,
      initialCategories: const [],
      initialStatus: BookStatus.wishlist,
      onSave: ({
        required String title,
        String? author,
        String? isbn,
        String? summary,
        required List<String> categoryIds,
      }) =>
          _save(
        title: title,
        author: author,
        isbn: isbn,
        summary: summary,
        categoryIds: categoryIds,
        coverUrl: prefilled?.coverUrl,
        status: BookStatus.wishlist,
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final BookCandidate candidate;
  final VoidCallback onTap;

  const _CandidateTile({required this.candidate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: candidate.coverUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                candidate.coverUrl!,
                width: 36,
                height: 54,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 36, height: 54),
              ),
            )
          : const SizedBox(width: 36, height: 54),
      title: Text(candidate.title,
          style: Theme.of(context).textTheme.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      subtitle: candidate.author != null
          ? Text(candidate.author!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis)
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
