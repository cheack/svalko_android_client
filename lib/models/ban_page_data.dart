class BanPageData {
  const BanPageData({
    required this.riddleQuestion,
    required this.riddleId,
    this.ipAddress = '',
  });

  final String riddleQuestion;
  final int riddleId;
  final String ipAddress;
}
