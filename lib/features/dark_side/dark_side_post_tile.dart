import 'package:flutter/material.dart';
import '../../models/dark_side_post.dart';
import '../../ui/widgets/image_carousel.dart';
import '../../ui/widgets/post_header.dart';

class DarkSidePostTile extends StatelessWidget {
  const DarkSidePostTile({super.key, required this.post});

  final DarkSidePost post;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostHeader(
            author: post.author.isEmpty ? 'Аноним' : post.author,
            publishedAt: post.publishedAt,
          ),
          if (post.imageUrls.isNotEmpty)
            ImageCarousel(urls: post.imageUrls, maxHeight: 400),
          if (post.text != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(post.text!),
            ),
        ],
      );
}
