import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/ui/widgets/attachment_widgets.dart';
import 'package:svalko_client/ui/widgets/post_form_shared.dart';

import 'support/fake_string_box.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('"В пост" inserts only for uploaded attachments; error tile has none', (tester) async {
    final uploading = Attachment(localPath: '/nope/a.png');
    final done = Attachment(localPath: '/nope/b.png')
      ..uploaded = const UploadedFile(code: 'https://i1.fastpic.org/big/x.jpg', deleteParam: '');
    final failed = Attachment(localPath: '/nope/c.png')..uploadError = 'fail';

    final inserted = <Attachment>[];
    await tester.pumpWidget(host(AttachmentRow(
      attachments: [uploading, done, failed],
      canAdd: true,
      onAdd: () {},
      onInsert: inserted.add,
      onDelete: (_) {},
    )));

    // Failed tile has no insert button.
    expect(find.text('В пост'), findsNWidgets(2));

    await tester.tap(find.text('В пост').first); // still uploading: disabled
    await tester.tap(find.text('В пост').last);
    expect(inserted, [done]);
  });

  testWidgets('add button fires only when enabled', (tester) async {
    var taps = 0;
    Widget row(bool canAdd) => host(AttachmentRow(
          attachments: const [],
          canAdd: canAdd,
          onAdd: () => taps++,
          onInsert: (_) {},
          onDelete: (_) {},
        ));

    await tester.pumpWidget(row(false));
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    expect(taps, 0);

    await tester.pumpWidget(row(true));
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    expect(taps, 1);
  });

  group('saveAttachments / restoreAttachments', () {
    test('round-trips uploaded attachments and skips unfinished ones', () {
      final box = FakeStringBox();
      final preview = File('${Directory.systemTemp.path}/att_${DateTime.now().microsecondsSinceEpoch}.png')
        ..writeAsBytesSync([1]);
      addTearDown(preview.deleteSync);

      saveAttachments(box, 'k', [
        Attachment(localPath: preview.path)
          ..uploaded = const UploadedFile(code: 'https://i1.fastpic.org/big/a.jpg', deleteParam: ''),
        Attachment(localPath: '/gone/b.png')
          ..uploaded = const UploadedFile(code: 'https://i1.fastpic.org/big/b.jpg', deleteParam: ''),
        Attachment(localPath: '/x/uploading.png'),
        Attachment(localPath: '/x/failed.png')..uploadError = 'fail',
      ]);

      final restored = restoreAttachments(box, 'k');
      expect(restored.map((a) => a.uploaded!.code),
          ['https://i1.fastpic.org/big/a.jpg', 'https://i1.fastpic.org/big/b.jpg']);
      expect(restored[0].localPath, preview.path);
      expect(restored[1].localPath, isNull); // preview file no longer exists
    });

    test('uses fallbackPath for entries saved without a local path', () {
      final box = FakeStringBox();
      saveAttachments(box, 'k', [
        Attachment()..uploaded = const UploadedFile(code: '[:|1.2|:]', deleteParam: '2'),
      ]);
      final restored = restoreAttachments(box, 'k', fallbackPath: (_) => '/missing.png');
      expect(restored.single.uploaded!.deleteParam, '2');
      expect(restored.single.localPath, isNull);
    });

    test('nothing saved restores an empty list', () {
      expect(restoreAttachments(FakeStringBox(), 'k'), isEmpty);
    });
  });
}
