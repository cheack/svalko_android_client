class SearchParams {
  const SearchParams({
    required this.query,
    this.order = 'rel',
    this.searchComments = true,
  });

  final String query;
  final String order; // 'rel' | 'date'
  final bool searchComments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchParams &&
          query == other.query &&
          order == other.order &&
          searchComments == other.searchComments;

  @override
  int get hashCode => Object.hash(query, order, searchComments);
}

class SearchResult {
  const SearchResult({
    required this.author,
    required this.publishedAt,
    required this.textHtml,
    required this.postId,
    this.commentId,
  });

  final String author;
  final DateTime publishedAt;
  final String textHtml;
  final int postId;
  final int? commentId;

  bool get isComment => commentId != null;
}
