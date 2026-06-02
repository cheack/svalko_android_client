sealed class FeedSource {
  const FeedSource();
}

class MainFeed extends FeedSource {
  const MainFeed();

  @override
  bool operator ==(Object other) => other is MainFeed;

  @override
  int get hashCode => 0;
}

class TagFeed extends FeedSource {
  const TagFeed({required this.tagId, required this.tagName});

  final int tagId;
  final String tagName;

  @override
  bool operator ==(Object other) =>
      other is TagFeed && other.tagId == tagId;

  @override
  int get hashCode => tagId.hashCode;
}

class AuthorFeed extends FeedSource {
  const AuthorFeed({required this.authorName, required this.profileUrl});

  final String authorName;
  // Full URL like https://svalko.org/?author=%D4%E8%E7%E8%EA%E5%EB%EB%E0
  // Keeps the already-encoded windows-1251 query intact.
  final String profileUrl;

  @override
  bool operator ==(Object other) =>
      other is AuthorFeed && other.authorName == authorName;

  @override
  int get hashCode => authorName.hashCode;
}

class ApproverFeed extends FeedSource {
  const ApproverFeed({required this.approverName});

  final String approverName;

  @override
  bool operator ==(Object other) =>
      other is ApproverFeed && other.approverName == approverName;

  @override
  int get hashCode => approverName.hashCode;
}

class DateFeed extends FeedSource {
  const DateFeed({required this.path, required this.label});

  /// Server-relative path, e.g. "/2026/04/13/"
  final String path;

  /// Human-readable label shown in the AppBar, e.g. "13 апреля 2026"
  final String label;

  @override
  bool operator ==(Object other) => other is DateFeed && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
