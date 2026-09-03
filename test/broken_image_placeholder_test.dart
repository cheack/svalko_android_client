import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/ui/widgets/broken_image_placeholder.dart';

void main() {
  testWidgets('shows the broken image icon and the failed url', (tester) async {
    const url = 'https://svalko.org/data/comments/broken.jpg';

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BrokenImagePlaceholder(url: url)),
    ));

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text(url), findsOneWidget);
  });
}
