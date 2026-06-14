import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/encoding.dart';
import '../../data/svalko_api.dart';

void restoreAndTrackDraft(TextEditingController ctrl, Box<String> box, String key) {
  final saved = box.get(key);
  if (saved != null) ctrl.text = saved;
  ctrl.addListener(() => box.put(key, ctrl.text));
}

void clearDraft(Box<String> box, String key) => box.delete(key);

void wrapBbCode(String tag, TextEditingController ctrl, FocusNode focus) {
  final text = ctrl.text;
  final sel = ctrl.selection;
  final start = sel.start.clamp(0, text.length);
  final end = sel.end.clamp(0, text.length);
  final selected = text.substring(start, end);
  final open = '[$tag]';
  final close = '[/$tag]';
  ctrl.value = TextEditingValue(
    text: text.replaceRange(start, end, '$open$selected$close'),
    selection: selected.isEmpty
        ? TextSelection.collapsed(offset: start + open.length)
        : TextSelection(
            baseOffset: start + open.length,
            extentOffset: start + open.length + selected.length,
          ),
  );
  focus.requestFocus();
}

Future<void> saveAuthorCookie(
  Box<String> settingsBox,
  SvalkoApi api,
  String authorKey,
  String author,
) async {
  settingsBox.put(authorKey, author);
  final encoded = await encodeQueryWin1251(author);
  final mynameCookie = 'myname=$encoded';
  settingsBox.put('mynameCookie', mynameCookie);
  api.mynameCookie = mynameCookie;
}

class BbCodeToolbar extends StatelessWidget {
  const BbCodeToolbar({super.key, required this.onWrap});
  final void Function(String tag) onWrap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (tag, label, style) in [
          ('b', 'B', TextStyle(fontWeight: FontWeight.bold)),
          ('i', 'I', TextStyle(fontStyle: FontStyle.italic)),
          ('u', 'U', TextStyle(decoration: TextDecoration.underline)),
          ('s', 'S', TextStyle(decoration: TextDecoration.lineThrough)),
        ])
          SizedBox(
            width: 36,
            height: 32,
            child: TextButton(
              onPressed: () => onWrap(tag),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(label, style: style),
            ),
          ),
      ],
    );
  }
}

class BbCodeTextField extends StatelessWidget {
  const BbCodeTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onWrap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String tag) onWrap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      minLines: 5,
      maxLines: 12,
      textInputAction: TextInputAction.newline,
      expands: false,
      contextMenuBuilder: (context, editableTextState) {
        final selection = editableTextState.textEditingValue.selection;
        final hasSelection = selection.isValid && !selection.isCollapsed;
        final items = [
          if (hasSelection) ...[
            for (final (tag, label) in [
              ('b', 'Жирный'),
              ('i', 'Курсив'),
              ('u', 'Подчёрк'),
              ('s', 'Зачёрк'),
            ])
              ContextMenuButtonItem(
                label: label,
                onPressed: () {
                  ContextMenuController.removeAny();
                  onWrap(tag);
                },
              ),
          ],
          ...editableTextState.contextMenuButtonItems,
        ];
        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: items,
        );
      },
    );
  }
}
