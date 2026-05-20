import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppSkin { blue, dark }

final skinProvider = StateProvider<AppSkin>((_) => AppSkin.blue);
