import 'package:flutter/foundation.dart';

@immutable
class DarkSidePost {
  const DarkSidePost({
    required this.id,
    required this.author,
    required this.publishedAt,
    required this.imageUrls,
    required this.externalLinks,
    this.text,
  });

  final int id;
  final String author;
  final DateTime publishedAt;
  final String? text;
  final List<String> imageUrls;
  final List<String> externalLinks;
}
