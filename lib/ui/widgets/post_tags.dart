import 'package:flutter/material.dart';
import '../../models/tag.dart';

class PostTagsRow extends StatelessWidget {
  const PostTagsRow({super.key, required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        children: tags
            .map(
              (t) => GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed('/tag', arguments: t),
                child: Text('#${t.name}', style: style),
              ),
            )
            .toList(),
      ),
    );
  }
}
