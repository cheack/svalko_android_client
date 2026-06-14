import 'package:flutter/foundation.dart';

@immutable
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.author,
    required this.publishedAt,
    required this.link,
    required this.descriptionHtml,
    this.imageUrl,
  });

  final int id;
  final String title;
  final String author;
  final DateTime? publishedAt;
  final Uri link;
  final String descriptionHtml;
  final Uri? imageUrl;

  String get displayTitle =>
      title.trim().isEmpty ? 'Новая запись' : title.trim();

  String get notificationBody {
    final cleanAuthor = author.trim();
    if (cleanAuthor.isEmpty) return displayTitle;
    return '$cleanAuthor: $displayTitle';
  }
}
