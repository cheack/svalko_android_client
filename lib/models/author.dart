import 'package:flutter/foundation.dart';

@immutable
class Author {
  const Author({required this.name, required this.profileUrl});

  final String name;
  final String profileUrl;

  @override
  bool operator ==(Object other) =>
      other is Author && other.name == name && other.profileUrl == profileUrl;

  @override
  int get hashCode => Object.hash(name, profileUrl);
}
