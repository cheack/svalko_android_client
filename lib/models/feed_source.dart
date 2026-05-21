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
