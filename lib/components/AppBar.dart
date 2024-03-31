import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class CAppBar extends StatefulWidget implements PreferredSizeWidget {
  CAppBar({ Key? key }) : preferredSize = const Size.fromHeight(kToolbarHeight), super(key: key);

  @override
  final Size preferredSize;

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CAppBar>{
  final debug = true;

  @override
  Widget build(BuildContext context) {
    return debug ? AppBar(
      surfaceTintColor: Colors.transparent,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 720,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xff15161a),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Expanded(
                    child: TextField(
                      style: TextStyle(fontFamily: 'Open Sans'),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: Color(0xff8a8a8c), fontWeight: FontWeight.w400),
                        labelStyle: TextStyle(color: Colors.red),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                      ),
                      maxLines: 1,
                    ),
                  ),
                  const Gap(8),
                  //https://stackoverflow.com/questions/55395641/outlined-transparent-button-with-gradient-border-in-flutter
                  UnicornOutlineButton(
                    strokeWidth: 3,
                    radius: 24,
                    gradient: const LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xfffd01d3), Color(0xff1d04f5), Color(0xff729aff), Color(0xffffffff)],
                        stops: [0, 0.5, 0.9, 1]
                    ),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      centerTitle: true,
      backgroundColor: const Color(0xff111214),
    ) : Container(
      height: 56,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xff262626),
        borderRadius: const BorderRadius.all(Radius.circular(9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff262626).withOpacity(0.3),
            offset: const Offset(0, 20),
            blurRadius: 20
          )
        ]
      ),
      child: Center(
        child: Text('Hello'),
      ),
    );
  }
}

class UnicornOutlineButton extends StatelessWidget {
  final _GradientPainter _painter;
  final Widget _child;
  final VoidCallback _callback;
  final double _radius;

  UnicornOutlineButton({super.key,
    required double strokeWidth,
    required double radius,
    required Gradient gradient,
    required Widget child,
    required VoidCallback onPressed,
  })  : _painter = _GradientPainter(strokeWidth: strokeWidth, radius: radius, gradient: gradient),
        _child = child,
        _callback = onPressed,
        _radius = radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _painter,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _callback,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: _callback,
          child: Container(
            constraints: const BoxConstraints(minWidth: 4, minHeight: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientPainter extends CustomPainter {
  final Paint _paint = Paint();
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientPainter({required this.strokeWidth, required this.radius, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    // create outer rectangle equals size
    Rect outerRect = Offset.zero & size;
    var outerRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(radius));

    // create inner rectangle smaller by strokeWidth
    Rect innerRect = Rect.fromLTWH(strokeWidth, strokeWidth, size.width - strokeWidth * 2, size.height - strokeWidth * 2);
    var innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(radius - strokeWidth));

    // apply gradient shader
    _paint.shader = gradient.createShader(outerRect);

    // create difference between outer and inner paths and draw it
    Path path1 = Path()..addRRect(outerRRect);
    Path path2 = Path()..addRRect(innerRRect);
    var path = Path.combine(PathOperation.difference, path1, path2);
    canvas.drawPath(path, _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => oldDelegate != this;
}