import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/ui/widgets/gif_player.dart';

void main() {
  testWidgets('failed frame decode does not crash the widget tree', (tester) async {
    // Not a real image at all, so the codec can't decode even the first
    // frame. This exercises the same uncaught-exception path as a
    // corrupt/truncated animated image ("Could not getPixels for frame N"):
    // decoding must fail gracefully instead of throwing past _loadFrames.
    final image = MemoryImage(Uint8List.fromList(List.filled(64, 0)));

    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Gif(image: image, useCache: false),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
