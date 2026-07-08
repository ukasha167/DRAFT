import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

int nowMs() => DateTime.now().millisecondsSinceEpoch;
