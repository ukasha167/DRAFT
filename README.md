# DRAFT.

> A beautifully designed, private digital sanctuary for book lovers. Track what you own, and curate what you wish to read.

**DRAFT** is an offline-first, professional personal book cataloguing application built for those who love to read. It combines minimal, distraction-free aesthetics with a fluid and therapeutic user interface.

## What is DRAFT?

DRAFT is designed to be your personal library companion. Whether you're standing in a bookstore wondering if you already own a specific title, or keeping track of recommendations from friends, DRAFT keeps your collection perfectly organized right in your pocket.

- **Your Library, Your Rules:** Organize your books into two dedicated spaces: **Library** (books currently on your shelf) and **Wishlist** (books you're hunting for).
- **Beautiful Organization:** Add custom categories to keep your collection sorted exactly how you like it. 
- **Instant Discovery:** Search through your entire catalogue instantly by title or author.
- **Add Books Effortlessly:** Quickly search for new books using our integrated lookup, pulling in covers, authors, and descriptions automatically.
- **Total Privacy:** DRAFT is entirely offline-first. Your library data is stored locally and securely on your own device. No accounts, no tracking, just you and your books.

## Getting Started

To run the application locally on your own machine:

1. Clone the repository.
2. Provide your own Google Books API key by creating a `lib/api_keys.dart` file:
   ```dart
   const googleBooksApiKey = 'YOUR_API_KEY';
   ```
3. Fetch dependencies and generate local database files:
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. Run the app:
   ```bash
   flutter run
   ```
