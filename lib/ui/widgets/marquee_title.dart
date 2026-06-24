import 'package:flutter/material.dart';

class MarqueeTitle extends StatefulWidget {
  const MarqueeTitle(this.text, {super.key});
  final String text;

  @override
  State<MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<MarqueeTitle> {
  final _controller = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  @override
  void didUpdateWidget(MarqueeTitle old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _controller.jumpTo(0);
      _loop();
    }
  }

  Future<void> _loop() async {
    if (_running) return;
    _running = true;
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) break;
      if (!_controller.hasClients) break;
      final max = _controller.position.maxScrollExtent;
      if (max <= 0) break;
      final ms = (max * 40).round();
      await _controller.animateTo(max,
          duration: Duration(milliseconds: ms), curve: Curves.linear);
      if (!mounted) break;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) break;
      await _controller.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
    _running = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text),
    );
  }
}
