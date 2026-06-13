import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

final favoritesBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

final favoriteCommentsBoxProvider =
    Provider<Box<String>>((_) => throw UnimplementedError());

class FavoritePost {
  const FavoritePost({
    required this.id,
    required this.authorName,
    required this.publishedAt,
    required this.addedAt,
    this.firstImageUrl,
    this.previewText,
  });

  final int id;
  final String authorName;
  final DateTime publishedAt;
  final DateTime addedAt;
  final String? firstImageUrl;
  final String? previewText;

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorName': authorName,
        'publishedAt': publishedAt.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        if (firstImageUrl != null) 'firstImageUrl': firstImageUrl,
        if (previewText != null) 'previewText': previewText,
      };

  factory FavoritePost.fromJson(Map<String, dynamic> json) => FavoritePost(
        id: json['id'] as int,
        authorName: json['authorName'] as String,
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        addedAt: DateTime.parse(json['addedAt'] as String),
        firstImageUrl: json['firstImageUrl'] as String?,
        previewText: json['previewText'] as String?,
      );
}

class FavoritesNotifier extends Notifier<List<FavoritePost>> {
  @override
  List<FavoritePost> build() {
    final box = ref.watch(favoritesBoxProvider);
    return box.values
        .map((v) {
          try {
            return FavoritePost.fromJson(
                jsonDecode(v) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoritePost>()
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  bool isFavorite(int postId) => state.any((f) => f.id == postId);

  void add(FavoritePost post) {
    final box = ref.read(favoritesBoxProvider);
    box.put('${post.id}', jsonEncode(post.toJson()));
    state = [post, ...state.where((f) => f.id != post.id)];
  }

  void remove(int postId) {
    final box = ref.read(favoritesBoxProvider);
    box.delete('$postId');
    state = state.where((f) => f.id != postId).toList();
  }

  void toggle(FavoritePost post) {
    if (isFavorite(post.id)) {
      remove(post.id);
    } else {
      add(post);
    }
  }

  /// Returns list of post JSON maps for combined export.
  List<Map<String, dynamic>> exportList() =>
      state.map((f) => f.toJson()).toList();

  /// Returns JSON string with all favorite posts (legacy single-type export).
  String exportJson() =>
      jsonEncode(state.map((f) => f.toJson()).toList());

  /// Merges favorites from a JSON list. Returns count of newly added items.
  int importList(List<dynamic> list) {
    final incoming = list
        .map((e) {
          try {
            return FavoritePost.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoritePost>()
        .toList();

    final existingIds = state.map((f) => f.id).toSet();
    final newItems = incoming.where((f) => !existingIds.contains(f.id)).toList();

    final box = ref.read(favoritesBoxProvider);
    for (final f in newItems) {
      box.put('${f.id}', jsonEncode(f.toJson()));
    }
    if (newItems.isNotEmpty) {
      state = [...newItems, ...state]
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return newItems.length;
  }

  /// Merges favorites from a JSON string (legacy format). Returns count added.
  int importJson(String json) => importList(jsonDecode(json) as List<dynamic>);
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoritePost>>(
        FavoritesNotifier.new);

// ---------------------------------------------------------------------------
// Favorite comments
// ---------------------------------------------------------------------------

class FavoriteComment {
  const FavoriteComment({
    required this.id,
    required this.postId,
    required this.commentPage,
    required this.authorName,
    required this.publishedAt,
    required this.addedAt,
    this.authorProfileUrl = '',
    this.previewText,
    this.textHtml,
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.isKum = false,
  });

  final int id;
  final int postId;
  final int commentPage;
  final String authorName;
  final DateTime publishedAt;
  final DateTime addedAt;
  final String authorProfileUrl;
  final String? previewText;
  final String? textHtml;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final bool isKum;

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'commentPage': commentPage,
        'authorName': authorName,
        if (authorProfileUrl.isNotEmpty) 'authorProfileUrl': authorProfileUrl,
        'publishedAt': publishedAt.toIso8601String(),
        'addedAt': addedAt.toIso8601String(),
        if (previewText != null) 'previewText': previewText,
        if (textHtml != null) 'textHtml': textHtml,
        if (imageUrls.isNotEmpty) 'imageUrls': imageUrls,
        if (videoUrls.isNotEmpty) 'videoUrls': videoUrls,
        if (isKum) 'isKum': isKum,
      };

  factory FavoriteComment.fromJson(Map<String, dynamic> json) =>
      FavoriteComment(
        id: json['id'] as int,
        postId: json['postId'] as int,
        commentPage: json['commentPage'] as int,
        authorName: json['authorName'] as String,
        authorProfileUrl: json['authorProfileUrl'] as String? ?? '',
        publishedAt: DateTime.parse(json['publishedAt'] as String),
        addedAt: DateTime.parse(json['addedAt'] as String),
        previewText: json['previewText'] as String?,
        textHtml: json['textHtml'] as String?,
        imageUrls: (json['imageUrls'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        videoUrls: (json['videoUrls'] as List<dynamic>? ?? [])
            .whereType<String>()
            .toList(),
        isKum: json['isKum'] == true,
      );
}

class FavoriteCommentsNotifier extends Notifier<List<FavoriteComment>> {
  @override
  List<FavoriteComment> build() {
    final box = ref.watch(favoriteCommentsBoxProvider);
    return box.values
        .map((v) {
          try {
            return FavoriteComment.fromJson(
                jsonDecode(v) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoriteComment>()
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  bool isFavorite(int commentId) => state.any((f) => f.id == commentId);

  void add(FavoriteComment comment) {
    final box = ref.read(favoriteCommentsBoxProvider);
    box.put('${comment.id}', jsonEncode(comment.toJson()));
    state = [comment, ...state.where((f) => f.id != comment.id)];
  }

  void remove(int commentId) {
    final box = ref.read(favoriteCommentsBoxProvider);
    box.delete('$commentId');
    state = state.where((f) => f.id != commentId).toList();
  }

  void toggle(FavoriteComment comment) {
    if (isFavorite(comment.id)) {
      remove(comment.id);
    } else {
      add(comment);
    }
  }

  List<Map<String, dynamic>> exportList() =>
      state.map((f) => f.toJson()).toList();

  int importList(List<dynamic> list) {
    final incoming = list
        .map((e) {
          try {
            return FavoriteComment.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FavoriteComment>()
        .toList();

    final existingIds = state.map((f) => f.id).toSet();
    final newItems =
        incoming.where((f) => !existingIds.contains(f.id)).toList();

    final box = ref.read(favoriteCommentsBoxProvider);
    for (final f in newItems) {
      box.put('${f.id}', jsonEncode(f.toJson()));
    }
    if (newItems.isNotEmpty) {
      state = [...newItems, ...state]
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    }
    return newItems.length;
  }
}

final favoriteCommentsProvider =
    NotifierProvider<FavoriteCommentsNotifier, List<FavoriteComment>>(
        FavoriteCommentsNotifier.new);
