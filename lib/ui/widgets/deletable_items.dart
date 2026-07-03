import 'dart:async';
import 'package:flutter/material.dart';

/// Adds animated delete-with-undo behavior to a list of items keyed by [int] id.
/// Call [startDelete] on delete, wrap each item with [wrapAnimated].
mixin DeletableItems<T extends StatefulWidget> on State<T> {
  final _deleting = <int>{};
  final _growing = <int>{};

  void startDelete(BuildContext context, int id, VoidCallback onRestore) {
    setState(() => _deleting.add(id));
    showUndoSnackBar(context, () {
      if (_deleting.contains(id)) {
        setState(() => _deleting.remove(id));
      } else {
        setState(() => _growing.add(id));
        onRestore();
      }
    });
  }

  Widget wrapAnimated(int id, Widget child, VoidCallback onRemove) {
    if (_deleting.contains(id)) {
      return AnimatedListItem(
        key: ValueKey(id),
        shrink: true,
        onEnd: () {
          onRemove();
          setState(() => _deleting.remove(id));
        },
        child: child,
      );
    }
    if (_growing.contains(id)) {
      return AnimatedListItem(
        key: ValueKey(id),
        shrink: false,
        onEnd: () => setState(() => _growing.remove(id)),
        child: child,
      );
    }
    return KeyedSubtree(key: ValueKey(id), child: child);
  }
}

void showUndoSnackBar(BuildContext context, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  Timer? timer;
  final ctrl = messenger.showSnackBar(SnackBar(
    duration: const Duration(days: 1),
    content: const Text('Удалено из избранного'),
    action: SnackBarAction(
      label: 'Отменить',
      onPressed: () {
        timer?.cancel();
        onUndo();
      },
    ),
  ));
  timer = Timer(const Duration(seconds: 5), ctrl.close);
  ctrl.closed.then((_) => timer?.cancel());
}

/// Shrink/grow + fade transition used when an item is deleted or restored.
class AnimatedListItem extends StatefulWidget {
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.shrink,
    required this.onEnd,
  });

  final Widget child;
  final bool shrink;
  final VoidCallback onEnd;

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _ctrl.forward().then((_) {
      if (mounted) widget.onEnd();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    final size = widget.shrink
        ? Tween<double>(begin: 1, end: 0).animate(curved)
        : Tween<double>(begin: 0, end: 1).animate(curved);
    final opacity = widget.shrink
        ? Tween<double>(begin: 1, end: 0).animate(curved)
        : Tween<double>(begin: 0, end: 1).animate(curved);
    return IgnorePointer(
      child: SizeTransition(
        sizeFactor: size,
        child: FadeTransition(opacity: opacity, child: widget.child),
      ),
    );
  }
}
