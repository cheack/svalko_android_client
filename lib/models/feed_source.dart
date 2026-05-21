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
