import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config.dart';
import '../../../core/open_url.dart';
import '../../../core/l10n.dart';
import '../../../core/settings_storage.dart';
import '../../../ui/skin_ext.dart';
import '../../../models/post.dart';
import '../../../models/feed_source.dart';
import '../../../ui/widgets/image_carousel.dart';
import '../../../ui/widgets/comment_html.dart';
import '../../../ui/widgets/post_action_buttons.dart';
import '../../../ui/widgets/post_tags.dart';
import '../../../ui/widgets/video_link_card.dart';
import '../../../ui/widgets/video_player_widget.dart';
import '../../../ui/widgets/post_vote_section.dart';
import '../../../ui/widgets/kum_shake.dart';
import '../../../ui/widgets/post_header.dart';


class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, required this.onTap, this.showApproverTap = true, this.showVoteSection = true});

  final Post post;
  final VoidCallback onTap;
  final bool showApproverTap;
  final bool showVoteSection;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  PostRating? _rating;
  int? _borodaCount;

  @override
  void initState() {
    super.initState();
    _rating = widget.post.rating;
    _borodaCount = widget.post.borodaCount;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(ref.watch(languageProvider));
    final theme = Theme.of(context);
    final dividers = theme.extension<SvalkoSkinExt>()?.cardDividers ?? false;

    return KumShake(
      enabled: widget.post.isKum,
      child: Container(
      margin: dividers
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: dividers
          ? null
          : BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
      child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: dividers ? const RoundedRectangleBorder() : null,
      child: InkWell(
        onLongPress: () => _showPostSheet(context, s, widget.post.id),
        child: Stack(
          children: [
            if (Theme.of(context).extension<SvalkoSkinExt>()?.cardPattern case final pattern?)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(image: pattern),
                ),
              ),
            Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkinHeader(
              child: PostHeader(
                author: widget.post.author.name,
                publishedAt: widget.post.publishedAt,
                rating: _rating,
                borodaCount: _borodaCount,
                approvedBy: widget.post.approvedBy,
                onAuthorTap: widget.onTap,
                onDateTap: () => Navigator.of(context).pushNamed(
                    '/date', arguments: DateFeed.fromDateTime(widget.post.publishedAt)),
                onApprovedByTap: (widget.post.approvedBy == null || !widget.showApproverTap)
                    ? null
                    : () => Navigator.of(context).pushNamed('/approver',
                        arguments: ApproverFeed(approverName: widget.post.approvedBy!)),
              ),
            ),
            if (widget.post.imageUrls.isNotEmpty)
              ImageCarousel(urls: widget.post.imageUrls),
            if (widget.post.imageUrls.isEmpty && widget.post.videoUrls.isNotEmpty)
              VideoPlayerWidget(url: widget.post.videoUrls.first),
            for (final link in widget.post.externalLinks)
              if (VideoLinkCard.isSupported(link))
                VideoLinkCard(url: link, onTap: widget.onTap),
            if (widget.post.textHtml != null && widget.post.textHtml!.isNotEmpty)
              InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: CommentHtml(
                    widget.post.textHtml!,
                    onSvalkoPost: (id) => Navigator.of(context)
                        .pushNamed('/post', arguments: id),
                  ),
                ),
              ),
            if (widget.post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: PostTagsRow(tags: widget.post.tags),
              ),
            if (widget.showVoteSection) PostVoteSection(
              postId: widget.post.id,
              rating: widget.post.rating,
              borodaCount: widget.post.borodaCount,
              parsedVote: widget.post.parsedVote,
              parsedBoroda: widget.post.parsedBoroda,
              availableVotes: widget.post.availableVotes,
              onRatingChanged: (r, bc) => setState(() {
                _rating = r;
                _borodaCount = bc;
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 12, 10),
              child: Row(
                children: [
                  PostFavButton(post: widget.post, iconSize: 18, visualDensity: VisualDensity.compact),
                  PostShareButton(postId: widget.post.id, iconSize: 18, visualDensity: VisualDensity.compact),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: widget.onTap,
                    icon: const Icon(Icons.comment_outlined, size: 14),
                    label: Text(s.commentsTooltip(widget.post.commentCount)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
          ),
        ],
        ),
      ),
    )));
  }

  static Future<void> _showPostSheet(
      BuildContext context, AppStrings s, int id) async {
    final postUrl = '${Config.baseUrl}/$id.html';
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser_outlined),
              title: Text(s.openInBrowser),
              onTap: () {
                Navigator.pop(sheetCtx);
                openInBrowser(context, postUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(s.shareLink),
              onTap: () {
                Navigator.pop(sheetCtx);
                Share.share(postUrl);
              },
            ),
          ],
        ),
      ),
    );
  }
}
