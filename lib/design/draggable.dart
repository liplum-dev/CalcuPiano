import 'package:flutter/widgets.dart';
import 'package:rettulf/rettulf.dart';

typedef KeyWidgetBuilder = Widget Function(BuildContext ctx, Key key);

class OmniDraggable extends StatefulWidget {
  final Offset offset;
  final Widget child;

  const OmniDraggable({super.key, required this.child, this.offset = Offset.zero});

  @override
  State<OmniDraggable> createState() => _OmniDraggableState();
}

class _OmniDraggableState extends State<OmniDraggable> with SingleTickerProviderStateMixin {
  var _x = 0.0;
  var _y = 0.0;
  final _mainBodyKey = GlobalKey();

  // Hide the first frame to avoid position flash
  double opacity = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final ctx = _mainBodyKey.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject();
        if (box is RenderBox) {
          final childSize = box.size;
          final selfSize = context.mediaQuery.size;
          setState(() {
            _x = (selfSize.width - childSize.width) / 2 + widget.offset.dx;
            _y = (selfSize.height - childSize.height) / 2 + widget.offset.dy;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
        opacity: opacity,
        child: [
          Positioned(
              key: _mainBodyKey,
              left: _x,
              top: _y,
              child: Listener(
                child: widget.child,
                onPointerMove: (d) {
                  setState(() {
                    _x += d.delta.dx;
                    _y += d.delta.dy;
                  });
                },
              ))
        ].stack());
  }
}

extension WidgetOmniDraggableX on Widget {
  OmniDraggable draggable({
    Key? key,
    Offset offset = Offset.zero,
  }) =>
      OmniDraggable(
        key: key,
        offset: offset,
        child: this,
      );
}
