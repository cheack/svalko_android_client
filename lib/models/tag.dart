import 'package:flutter/foundation.dart';

@immutable
class Tag {
  const Tag({required this.id, required this.name, this.count});

  final int id;
  final String name;
  final int? count;

  factory Tag.fromJson(Map<String, dynamic> j) =>
      Tag(id: j['id'] as int, name: j['name'] as String, count: j['count'] as int?);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'count': count};

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
