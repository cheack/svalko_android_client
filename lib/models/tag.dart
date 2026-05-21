import 'package:flutter/foundation.dart';

@immutable
class Tag {
  const Tag({required this.id, required this.name, this.count});

  final int id;
  final String name;
  final int? count;

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
