import 'package:flutter/foundation.dart';

/// A piece of a dark-side post's body — either plain text or a clickable link.
@immutable
sealed class DarkSideTextPart {
  const DarkSideTextPart();
}

@immutable
class DarkSideText extends DarkSideTextPart {
  const DarkSideText(this.text);
  final String text;
}

@immutable
class DarkSideLink extends DarkSideTextPart {
  const DarkSideLink(this.label, this.url);
  final String label;
  final String url;
}

@immutable
class DarkSidePost {
  const DarkSidePost({
    required this.id,
    required this.author,
    required this.publishedAt,
    required this.imageUrls,
    required this.textParts,
    this.approvedBy,
    this.approverComment,
    this.authorPostCount,
  });

  final int id;
  final String author;
  final DateTime publishedAt;
  final List<DarkSideTextPart> textParts;
  final List<String> imageUrls;
  final String? approvedBy;
  final String? approverComment;
  /// Total post count for [author], parsed from "Всего постов: N".
  final int? authorPostCount;

  /// All link URLs found in [textParts], in order.
  List<String> get externalLinks => textParts
      .whereType<DarkSideLink>()
      .map((p) => p.url)
      .toList();

  bool get hasText =>
      textParts.any((p) => p is! DarkSideText || p.text.trim().isNotEmpty);
}
