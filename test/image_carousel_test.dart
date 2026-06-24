import 'package:flutter_test/flutter_test.dart';
import 'package:svalko_client/ui/widgets/image_carousel.dart';

void main() {
  group('isInsideContainedImage', () {
    // Portrait image (1:2) in a landscape container (400×320):
    // rendered size = 160×320, left padding = 120, right padding = 120
    const containerW = 400.0;
    const containerH = 320.0;
    const portraitRatio = 0.5; // 1:2

    test('tap inside portrait image returns true', () {
      expect(isInsideContainedImage(const Offset(200, 160), containerW, containerH, portraitRatio), isTrue);
    });

    test('tap on left transparent padding returns false', () {
      expect(isInsideContainedImage(const Offset(10, 160), containerW, containerH, portraitRatio), isFalse);
    });

    test('tap on right transparent padding returns false', () {
      expect(isInsideContainedImage(const Offset(390, 160), containerW, containerH, portraitRatio), isFalse);
    });

    // Wide image (2:1) in the same container — fills width, letterboxed top/bottom
    // rendered size = 400×200, top padding = 60
    const wideRatio = 2.0;

    test('tap inside wide image returns true', () {
      expect(isInsideContainedImage(const Offset(200, 160), containerW, containerH, wideRatio), isTrue);
    });

    test('tap on top letterbox of wide image returns false', () {
      expect(isInsideContainedImage(const Offset(200, 10), containerW, containerH, wideRatio), isFalse);
    });

    test('tap on bottom letterbox of wide image returns false', () {
      expect(isInsideContainedImage(const Offset(200, 310), containerW, containerH, wideRatio), isFalse);
    });

    // Square image in the container — height-constrained: rendered 320×320, side padding = 40
    const squareRatio = 1.0;

    test('tap inside square image returns true', () {
      expect(isInsideContainedImage(const Offset(200, 160), containerW, containerH, squareRatio), isTrue);
    });

    test('tap on side padding of square image returns false', () {
      expect(isInsideContainedImage(const Offset(20, 160), containerW, containerH, squareRatio), isFalse);
    });
  });
}
