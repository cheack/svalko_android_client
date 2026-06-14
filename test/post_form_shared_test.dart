import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/ui/widgets/post_form_shared.dart';

void main() {
  group('wrapBbCode', () {
    late TextEditingController ctrl;
    late FocusNode focus;

    setUp(() {
      ctrl = TextEditingController();
      focus = FocusNode();
    });

    tearDown(() {
      ctrl.dispose();
      focus.dispose();
    });

    test('wraps empty selection — inserts tags and places cursor inside', () {
      ctrl.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 2),
      );
      wrapBbCode('b', ctrl, focus);
      expect(ctrl.text, 'he[b][/b]llo');
      expect(ctrl.selection.baseOffset, 5); // after [b]
    });

    test('wraps selected text', () {
      ctrl.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 6, extentOffset: 11),
      );
      wrapBbCode('i', ctrl, focus);
      expect(ctrl.text, 'hello [i]world[/i]');
      expect(ctrl.selection.baseOffset, 9);   // start of selected text
      expect(ctrl.selection.extentOffset, 14); // end of selected text
    });

    test('wraps full text when all selected', () {
      ctrl.value = const TextEditingValue(
        text: 'bold',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );
      wrapBbCode('b', ctrl, focus);
      expect(ctrl.text, '[b]bold[/b]');
    });

    test('inserts at start of empty string', () {
      ctrl.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      wrapBbCode('u', ctrl, focus);
      expect(ctrl.text, '[u][/u]');
      expect(ctrl.selection.baseOffset, 3);
    });

    test('invalid selection falls back to end of text', () {
      ctrl.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: -1),
      );
      wrapBbCode('s', ctrl, focus);
      expect(ctrl.text, '[s][/s]abc');
    });
  });

  group('parseUploadedFiles', () {
    test('returns empty for "nothing yet" page', () {
      const html = '<html><body>'
          '<div>Тут будет список залитых файлов. Пока ничего нет.</div>'
          '</body></html>';
      expect(parseUploadedFiles(html), isEmpty);
    });

    test('parses single file from success response', () {
      const html = '<html><body>'
          '<div>Список залитых файлов: </div>'
          '<div id="file_1"><nobr>файл [:|522815.1|:]</nobr></div>'
          '</body></html>';
      final files = parseUploadedFiles(html);
      expect(files.length, 1);
      expect(files[0].code, '[:|522815.1|:]');
      expect(files[0].deleteParam, '1');
    });

    test('parses multiple files', () {
      const html = '<html><body>'
          'файл [:|522815.1|:] файл [:|522815.2|:]'
          '</body></html>';
      final files = parseUploadedFiles(html);
      expect(files.length, 2);
      expect(files[1].code, '[:|522815.2|:]');
      expect(files[1].deleteParam, '2');
    });

    test('error response with existing file returns only existing file', () {
      // Server returns ЕГГОГ for the new upload but still lists the old file.
      // The caller must detect this by checking for a new (unknown) code.
      const html = '<html><body>'
          '<div style="border: 2px solid; background-color: #faa;">'
          'ЕГГОГ: Какая-то ошибка случилась!'
          '</div>'
          '<div id="file_1"><nobr>файл [:|522815.1|:]</nobr></div>'
          '</body></html>';
      final files = parseUploadedFiles(html);
      expect(files.length, 1);
      expect(files[0].code, '[:|522815.1|:]');
    });

    test('error response with no prior files returns empty', () {
      const html = '<html><body>'
          '<div>Тут будет список залитых файлов. Пока ничего нет.</div>'
          '<div style="border: 2px solid; background-color: #faa;">'
          'ЕГГОГ: Какая-то ошибка случилась!'
          '</div>'
          '</body></html>';
      expect(parseUploadedFiles(html), isEmpty);
    });
  });
}
