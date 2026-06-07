import 'package:flutter/foundation.dart';

enum TopicAge { normal, old, veryOld }

@immutable
class LastComment {
  const LastComment({
    required this.author,
    required this.postId,
    required this.commentId,
    required this.postTitle,
    required this.commentText,
    required this.commentCount,
    required this.topicAge,
  });

  final String author;
  final int postId;
  final int commentId;
  final String postTitle;
  final String commentText;
  final int commentCount;
  final TopicAge topicAge;
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
