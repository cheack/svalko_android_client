import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

final favoritesBoxProvider =
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
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoritePost>>(
        FavoritesNotifier.new);
