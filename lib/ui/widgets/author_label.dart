import 'package:flutter/material.dart';

class AuthorLabel extends StatelessWidget {
  const AuthorLabel({super.key, required this.controller, required this.theme});

  final TextEditingController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Я, ', style: theme.textTheme.bodyMedium),
        Flexible(
          child: IntrinsicWidth(
            child: TextField(
              controller: controller,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 2),
                border: UnderlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
        ),
        Text(', хочу послать нижеследующее:', style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
