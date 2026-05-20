import 'package:flutter/material.dart';
import '../../models/tag.dart';

class PostTagsRow extends StatelessWidget {
  const PostTagsRow({super.key, required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map((t) => Chip(
                label: Text(t.name),
                labelStyle: style,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ))
          .toList(),
      ),
    );
  }
}
