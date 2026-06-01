import 'package:flutter/foundation.dart';
import 'author.dart';
import 'tag.dart';

@immutable
class PostRating {
  const PostRating({
    required this.plus,
    required this.neutral,
    required this.minus,
    required this.percentage,
  });

  final int plus;
  final int neutral;
  final int minus;
  final int percentage;
}

@immutable
class Post {
  const Post({
    required this.id,
    required this.author,
    required this.publishedAt,
    required this.imageUrls,
    required this.videoUrls,
    required this.externalLinks,
    required this.tags,
    required this.commentCount,
    this.text,
    this.textHtml,
    this.rating,
    this.borodaCount,
    this.approvedBy,
    this.textLength,
    this.sheepCount,
    this.parsedVote,
    this.parsedBoroda,
    this.availableVotes,
  });

  final int id;
  final Author author;
  final DateTime publishedAt;
  final String? text;
  final String? textHtml;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final List<String> externalLinks;
  final List<Tag> tags;
  final PostRating? rating;
  final int? borodaCount;
  final int commentCount;
  final String? approvedBy;
  final int? textLength;
  final int? sheepCount;
  final int? parsedVote;
  final bool? parsedBoroda;
  final List<int>? availableVotes;
}
