import 'package:flutter/material.dart';

Widget debugSubHeader(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  child: Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ),
);

Widget debugTile({required String title, required VoidCallback onPressed}) =>
    ListTile(
      title: Text(title),
      trailing: TextButton(onPressed: onPressed, child: const Text('Отправить')),
    );
