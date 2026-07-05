import 'dart:collection';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../../api_keys.dart';
import '../book_lookup_repository.dart';

class GoogleBooksRepository implements BookLookupRepository {
  // Set your key in Cloud Console: restrict to package name + signing cert.
  static const _apiKey = googleBooksApiKey;
  static const _gbBase = 'https://www.googleapis.com/books/v1/volumes';
  static const _olBase = 'https://openlibrary.org/search.json';

  final Dio _dio;

  // Simple in-memory cache keyed by normalized query string.
  // Evicts oldest entry when capacity is reached.
  final _cache = LinkedHashMap<String, List<BookCandidate>>();
  static const _cacheCapacity = 50;

  GoogleBooksRepository()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        );

  @override
  Future<List<BookCandidate>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return [];

    // Cache hit — skip network entirely.
    if (_cache.containsKey(normalized)) {
      // Refresh access order.
      final hit = _cache.remove(normalized)!;
      _cache[normalized] = hit;
      return hit;
    }

    // Fast pre-check: if we clearly have no connectivity, skip the network
    // call and go straight to the empty / manual-entry path.
    // Note: connectivity_plus reports interface state, NOT internet reachability.
    // It can say "connected" on a dead upstream — the actual request timeout
    // is the real gate. This is only a fast-path skip for obviously offline cases.
    final connectivity = await Connectivity().checkConnectivity();
    final hasInterface =
        connectivity.any((r) => r != ConnectivityResult.none);

    if (!hasInterface) return [];

    // Try Google Books API. If it fails, fall back immediately.
    List<BookCandidate>? results;
    try {
      results = await _fetchGoogleBooks(query);
    } catch (_) {
      results = null; // Fall through to Open Library.
    }

    if (results != null && results.isNotEmpty) {
      _store(normalized, results);
      return results;
    }

    // Fall through to Open Library.
    try {
      results = await _fetchOpenLibrary(query);
    } catch (_) {
      results = [];
    }

    _store(normalized, results ?? []);
    return results ?? [];
  }

  // ---------------------------------------------------------------------------

  Future<List<BookCandidate>> _fetchGoogleBooks(String query) async {
    final params = <String, dynamic>{
      'q': query,
      'maxResults': 10,
      'printType': 'books',
      if (_apiKey.isNotEmpty && _apiKey != 'YOUR_GOOGLE_BOOKS_API_KEY')
        'key': _apiKey,
    };

    final resp = await _dio.get<Map<String, dynamic>>(
      _gbBase,
      queryParameters: params,
    );

    if (resp.statusCode == 429) {
      throw const _RateLimitException();
    }

    final items =
        (resp.data?['items'] as List<dynamic>?) ?? [];

    return items.map((item) {
      final info =
          (item as Map<String, dynamic>)['volumeInfo'] as Map<String, dynamic>?;
      if (info == null) return null;

      final authors = (info['authors'] as List<dynamic>?)?.cast<String>();
      final identifiers =
          (info['industryIdentifiers'] as List<dynamic>?) ?? [];
      String? isbn;
      for (final id in identifiers) {
        final type = (id as Map)['type'] as String?;
        if (type == 'ISBN_13' || type == 'ISBN_10') {
          isbn = id['identifier'] as String?;
          if (type == 'ISBN_13') break;
        }
      }

      final imageLinks =
          info['imageLinks'] as Map<String, dynamic>?;
      String? coverUrl = imageLinks?['thumbnail'] as String?;
      // Upgrade http → https (Google Books returns http thumbnails).
      if (coverUrl != null && coverUrl.startsWith('http:')) {
        coverUrl = 'https${coverUrl.substring(4)}';
      }

      return BookCandidate(
        title: (info['title'] as String?) ?? 'Unknown',
        author: authors?.join(', '),
        isbn: isbn,
        description: info['description'] as String?,
        coverUrl: coverUrl,
        source: 'google_books',
      );
    }).whereType<BookCandidate>().toList();
  }

  Future<List<BookCandidate>> _fetchOpenLibrary(String query) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      _olBase,
      queryParameters: {'q': query, 'limit': 10},
    );

    final docs = (resp.data?['docs'] as List<dynamic>?) ?? [];

    return docs.map((doc) {
      final d = doc as Map<String, dynamic>;
      final authors =
          (d['author_name'] as List<dynamic>?)?.cast<String>();
      final isbns = (d['isbn'] as List<dynamic>?)?.cast<String>();

      final coverId = d['cover_i'];
      final coverUrl = coverId != null
          ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
          : null;

      return BookCandidate(
        title: (d['title'] as String?) ?? 'Unknown',
        author: authors?.first,
        isbn: isbns?.isNotEmpty == true ? isbns!.first : null,
        description: null, // Open Library search doesn't return descriptions.
        coverUrl: coverUrl,
        source: 'open_library',
      );
    }).whereType<BookCandidate>().toList();
  }

  void _store(String key, List<BookCandidate> value) {
    if (_cache.length >= _cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}

class _RateLimitException implements Exception {
  const _RateLimitException();
}
