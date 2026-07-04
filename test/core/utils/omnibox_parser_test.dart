import 'package:flutter_test/flutter_test.dart';
import 'package:book_tracker/core/utils/omnibox_parser.dart';

void main() {
  group('parseOmnibox', () {
    // ------------------------------------------------------------------
    // Base cases
    // ------------------------------------------------------------------
    test('empty string → isEmpty', () {
      expect(parseOmnibox('').isEmpty, isTrue);
    });

    test('whitespace-only → isEmpty', () {
      expect(parseOmnibox('   ').isEmpty, isTrue);
    });

    // ------------------------------------------------------------------
    // Single token types
    // ------------------------------------------------------------------
    test('plain text', () {
      final q = parseOmnibox('tolkien');
      expect(q.text, 'tolkien');
      expect(q.categories, isEmpty);
      expect(q.viewCommand, isNull);
    });

    test('multi-word text', () {
      final q = parseOmnibox('lord of the rings');
      expect(q.text, 'lord of the rings');
    });

    test('#tag alone', () {
      final q = parseOmnibox('#fantasy');
      expect(q.text, isNull);
      expect(q.categories, ['fantasy']);
      expect(q.viewCommand, isNull);
    });

    test('#tag is lowercased', () {
      expect(parseOmnibox('#Fantasy').categories, ['fantasy']);
      expect(parseOmnibox('#SCI-FI').categories, ['sci-fi']);
    });

    test('bare # without text is ignored as category', () {
      // '#' alone has length 1; per spec it's not a category token.
      final q = parseOmnibox('#');
      expect(q.categories, isEmpty);
      expect(q.text, '#');
    });

    test(':owned command', () {
      final q = parseOmnibox(':owned');
      expect(q.viewCommand, 'owned');
      expect(q.text, isNull);
    });

    test(':wishlist command', () {
      final q = parseOmnibox(':wishlist');
      expect(q.viewCommand, 'wishlist');
    });

    test('unknown :command is preserved as text', () {
      final q = parseOmnibox(':sort');
      expect(q.text, ':sort');
      expect(q.viewCommand, isNull);
    });

    // ------------------------------------------------------------------
    // AND combinations
    // ------------------------------------------------------------------
    test('text + #tag', () {
      final q = parseOmnibox('dune #scifi');
      expect(q.text, 'dune');
      expect(q.categories, ['scifi']);
      expect(q.viewCommand, isNull);
    });

    test('text + :command', () {
      final q = parseOmnibox('asimov :owned');
      expect(q.text, 'asimov');
      expect(q.viewCommand, 'owned');
    });

    test('#tag + :command', () {
      final q = parseOmnibox('#fantasy :wishlist');
      expect(q.categories, ['fantasy']);
      expect(q.viewCommand, 'wishlist');
      expect(q.text, isNull);
    });

    test('full combination: text + #tag + :command', () {
      final q = parseOmnibox('tolkien #fantasy :owned');
      expect(q.text, 'tolkien');
      expect(q.categories, ['fantasy']);
      expect(q.viewCommand, 'owned');
    });

    test('multiple #tags all captured', () {
      final q = parseOmnibox('#scifi #dystopia #classics');
      expect(q.categories, ['scifi', 'dystopia', 'classics']);
    });

    test('tokens can appear in any order', () {
      final a = parseOmnibox('#fantasy tolkien :owned');
      final b = parseOmnibox(':owned tolkien #fantasy');
      expect(a.text, b.text);
      expect(a.categories, b.categories);
      expect(a.viewCommand, b.viewCommand);
    });

    // ------------------------------------------------------------------
    // Edge cases
    // ------------------------------------------------------------------
    test('last :command wins when multiple appear', () {
      final q = parseOmnibox(':owned :wishlist');
      expect(q.viewCommand, 'wishlist');
    });

    test('leading/trailing whitespace stripped', () {
      expect(parseOmnibox('  tolkien  ').text, 'tolkien');
    });

    test('hasFilters is false for empty, true otherwise', () {
      expect(parseOmnibox('').hasFilters, isFalse);
      expect(parseOmnibox('x').hasFilters, isTrue);
      expect(parseOmnibox('#tag').hasFilters, isTrue);
      expect(parseOmnibox(':owned').hasFilters, isTrue);
    });

    test('ParsedQuery equality', () {
      expect(
        parseOmnibox('tolkien #fantasy :owned'),
        equals(parseOmnibox('tolkien #fantasy :owned')),
      );
      expect(
        parseOmnibox('tolkien #fantasy'),
        isNot(equals(parseOmnibox('tolkien #scifi'))),
      );
    });
  });
}
