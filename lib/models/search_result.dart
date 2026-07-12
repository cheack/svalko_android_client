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
    this.isDirectMatch = false,
  });

  final String author;
  final DateTime publishedAt;
  final String textHtml;
  final int postId;
  final int? commentId;
  final bool isDirectMatch;

  bool get isComment => commentId != null;
}

/// Extracts a numeric post id from a svalko.org post URL, e.g.
/// `https://svalko.org/1023061.html` -> `1023061`, or from a bare id, e.g.
/// `1023061`. Returns null otherwise.
int? extractSvalkoPostId(String query) {
  final trimmed = query.trim();
  final urlMatch = RegExp(
    r'^https?://(?:www\.)?svalko\.org/(\d+)\.html/?$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (urlMatch != null) return int.tryParse(urlMatch.group(1)!);

  if (RegExp(r'^\d+$').hasMatch(trimmed)) return int.tryParse(trimmed);

  return null;
}
