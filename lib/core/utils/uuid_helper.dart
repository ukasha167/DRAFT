import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a new UUID v4 primary key.
/// Client-generated so two devices never collide once cloud sync ships.
String newId() => _uuid.v4();

/// Current epoch time in milliseconds — used for created_at / updated_at.
int nowMs() => DateTime.now().millisecondsSinceEpoch;
