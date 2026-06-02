import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/core/result.dart';
import 'package:svalko_client/data/parsers/post_parser.dart';
import 'package:svalko_client/data/repositories/svalko_repository.dart';
import 'package:svalko_client/features/post/post_controller.dart';
import 'package:svalko_client/models/author.dart';
import 'package:svalko_client/models/post.dart';

PostPage _page({int totalPages = 1, int totalComments = 10, int currentPage = 0}) =>
    PostPage(
      post: Post(
        id: 1,
        author: const Author(name: 'Test', profileUrl: ''),
        publishedAt: DateTime(2024),
        imageUrls: const [],
        videoUrls: const [],
        externalLinks: const [],
        tags: const [],
        commentCount: totalComments,
      ),
      comments: const [],
      pagination: CommentsPaginationInfo(
        currentPage: currentPage,
        totalPages: totalPages,
        totalComments: totalComments,
      ),
    );

typedef _GetPost = Future<Result<PostPage, AppError>> Function(
    int? commentsPage, bool isHistorical);


class _Repo extends SvalkoRepository {
  _Repo({_GetPost? onGetPost})
      : _onGetPost = onGetPost ?? ((_, _) async => Ok(_page()));

  _GetPost _onGetPost;

  set onGetPost(_GetPost fn) => _onGetPost = fn;

  int? lastCommentsPage;
  bool? lastIsHistorical;

  @override
  Future<Result<PostPage, AppError>> getPost(
    int id, {
    int? commentsPage,
    bool isHistorical = false,
  }) {
    lastCommentsPage = commentsPage;
    lastIsHistorical = isHistorical;
    return _onGetPost(commentsPage, isHistorical);
  }
}

void main() {
  group('PostController.refresh', () {
    test('updates totalPages and totalComments from server', () async {
      final repo = _Repo(
          onGetPost: (_, _) async => Ok(_page(totalPages: 2, totalComments: 30)));
      final ctrl = PostController(repo, 1);
      await Future.delayed(Duration.zero);

      repo.onGetPost = (_, _) async => Ok(_page(totalPages: 5, totalComments: 99));
      await ctrl.refresh();

      expect(ctrl.state.totalPages, 5);
      expect(ctrl.state.totalComments, 99);
      expect(ctrl.state.isLoadingMore, false);
    });

    test('always uses isHistorical: false', () async {
      final repo = _Repo();
      final ctrl = PostController(repo, 1);
      await Future.delayed(Duration.zero);

      bool? capturedHistorical;
      repo.onGetPost = (_, isHistorical) async {
        capturedHistorical = isHistorical;
        return Ok(_page());
      };
      await ctrl.refresh();

      expect(capturedHistorical, false);
    });

    test('requests page 0 as null commentsPage', () async {
      final repo = _Repo();
      final ctrl = PostController(repo, 1);
      await Future.delayed(Duration.zero);

      int? capturedPage = -1;
      repo.onGetPost = (commentsPage, _) async {
        capturedPage = commentsPage;
        return Ok(_page());
      };
      await ctrl.refresh();

      expect(capturedPage, null);
    });

    test('requests current page when not on page 0', () async {
      final repo = _Repo(
          onGetPost: (_, _) async => Ok(_page(totalPages: 3, currentPage: 0)));
      final ctrl = PostController(repo, 1);
      await Future.delayed(Duration.zero);

      repo.onGetPost = (_, _) async => Ok(_page(totalPages: 3, currentPage: 2));
      await ctrl.loadPage(2);

      int? capturedPage = -1;
      repo.onGetPost = (commentsPage, _) async {
        capturedPage = commentsPage;
        return Ok(_page(totalPages: 3, currentPage: 2));
      };
      await ctrl.refresh();

      expect(capturedPage, 2);
    });

    test('is a no-op while initial load is in progress', () async {
      final completer = Completer<Result<PostPage, AppError>>();
      final repo = _Repo(onGetPost: (_, _) => completer.future);
      final ctrl = PostController(repo, 1);

      expect(ctrl.state.isLoading, true);
      await ctrl.refresh();
      expect(ctrl.state.isLoading, true);
      expect(ctrl.state.isLoadingMore, false);

      completer.complete(Ok(_page()));
    });

    test('is a no-op while another page load is in progress', () async {
      final repo = _Repo(
          onGetPost: (_, _) async => Ok(_page(totalPages: 3, currentPage: 0)));
      final ctrl = PostController(repo, 1);
      await Future.delayed(Duration.zero);

      final stuck = Completer<Result<PostPage, AppError>>();
      repo.onGetPost = (_, _) => stuck.future;
      ctrl.loadPage(1);

      expect(ctrl.state.isLoadingMore, true);
      await ctrl.refresh();
      expect(ctrl.state.isLoadingMore, true);

      stuck.complete(Ok(_page(totalPages: 3, currentPage: 1)));
    });

    test('sets error and clears isLoadingMore on failure', () async {
      final repo = _Repo();
      final ctrl = PostController(repo, 1);
      await Future.delayed(Duration.zero);

      repo.onGetPost = (_, _) async => const Err(AppError.network);
      await ctrl.refresh();

      expect(ctrl.state.error, AppError.network);
      expect(ctrl.state.isLoadingMore, false);
    });
  });
}
