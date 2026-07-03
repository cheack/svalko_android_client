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
    this.approverCommentParts = const [],
    this.authorPostCount,
  });

  final int id;
  final String author;
  final DateTime publishedAt;
  final List<DarkSideTextPart> textParts;
  final List<String> imageUrls;
  final String? approvedBy;
  final String? approverComment;
  /// [approverComment] split into text/link parts — plain-text URLs in the
  /// attribution line (e.g. "Unwaiter: рекомендую https://...") are not real
  /// `<a>` tags on the site, so they're auto-linkified here.
  final List<DarkSideTextPart> approverCommentParts;
  /// Total post count for [author], parsed from "Всего постов: N".
  final int? authorPostCount;

  /// All link URLs found in [textParts], in order.
  List<String> get externalLinks => textParts
      .whereType<DarkSideLink>()
      .map((p) => p.url)
      .toList();

  bool get hasText =>
      textParts.any((p) => p is! DarkSideText || p.text.trim().isNotEmpty);

  /// Concatenated plain text of [textParts] (link labels included), for
  /// previews where clickability doesn't matter.
  String get plainText => textParts
      .map((p) => switch (p) {
            DarkSideText(:final text) => text,
            DarkSideLink(:final label) => label,
          })
      .join()
      .trim();
}
