import 'package:flutter/foundation.dart';
import 'author.dart';

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.publishedAt,
    required this.imageUrls,
    required this.videoUrls,
    this.text,
  });

  final int id;
  final int postId;
  final Author author;
  final DateTime publishedAt;
  final String? text;
  final List<String> imageUrls;
  final List<String> videoUrls;
}
