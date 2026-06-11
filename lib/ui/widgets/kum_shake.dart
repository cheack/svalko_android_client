import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class KumShake extends StatefulWidget {
  const KumShake({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<KumShake> createState() => _KumShakeState();
}

class _KumShakeState extends State<KumShake> {
  Timer? _timer;
  Offset _offset = Offset.zero;
  static final _rng = Random();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _start();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _offset = Offset(_rng.nextDouble() * 10 - 5, _rng.nextDouble() * 8 - 4);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Transform.translate(offset: _offset, child: widget.child);
  }
}
