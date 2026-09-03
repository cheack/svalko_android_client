import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression test for a crash reported in production:
//   RangeError (length): Invalid value: Not in inclusive range 0..3: 104
//   ...MultiSelectableSelectionContainerDelegate.getSelectionGeometry...
//
// Root cause: post_screen.dart wrapped the whole post+comments ListView in a
// single top-level SelectionArea. The comments list is entirely replaced
// (different length/content) on every page navigation, so the selection
// container's registered selectables went stale mid-layout. The fix scopes
// selection per comment tile (mirroring dark_side_feed_screen's per-item
// SelectionArea) and excludes the changing comments block from the outer
// SelectionArea via SelectionContainer.disabled. This test mounts that same
// structural pattern and repeatedly swaps the item list — as pagination
// does — to make sure it survives without throwing.
void main() {
  testWidgets('comments list can change length under selection without RangeError',
      (tester) async {
    List<int> ids = List.generate(4, (i) => i);

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, setState) {
        return Scaffold(
          body: SelectionArea(
            child: ListView(
              children: [
                const Text('Post body'),
                SelectionContainer.disabled(
                  child: Column(
                    children: [
                      for (final id in ids)
                        SelectionArea(
                          key: ValueKey(id),
                          child: Text('Comment $id'),
                        ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => setState(() => ids = List.generate(104, (i) => i)),
                  child: const Text('page 1'),
                ),
              ],
            ),
          ),
        );
      }),
    ));

    // Simulate a text selection being (or having just been) active over the
    // list before pagination swaps the comments out from under it.
    await tester.longPress(find.text('Post body'));
    await tester.pump();

    await tester.tap(find.text('page 1'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
