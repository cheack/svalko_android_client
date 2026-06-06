import 'package:flutter/foundation.dart';

@immutable
class LastComment {
  const LastComment({
    required this.author,
    required this.postId,
    required this.commentId,
    required this.postTitle,
    required this.commentText,
    required this.commentCount,
    required this.isOldTopic,
  });

  final String author;
  final int postId;
  final int commentId;
  final String postTitle;
  final String commentText;
  final int commentCount;
  final bool isOldTopic;
}

@immutable
class LastImage {
  const LastImage({
    required this.author,
    required this.postId,
    required this.commentId,
    required this.thumbUrl,
  });

  final String author;
  final int postId;
  final int commentId;
  final String thumbUrl;
}
