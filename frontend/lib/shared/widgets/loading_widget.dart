import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final double? size;
  final Color? color;
  final Color? backgroundColor;
  final String? message;
  final EdgeInsets padding;
  final bool showMessage;

  const LoadingWidget({
    super.key,
    this.size,
    this.color,
    this.backgroundColor,
    this.message,
    this.padding = const EdgeInsets.all(16.0),
    this.showMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8.0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: size ?? 40.0,
                  height: size ?? 40.0,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      color ?? Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                if (showMessage && message != null) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Alternative: Full screen loading overlay
class FullScreenLoading extends StatelessWidget {
  final String? message;
  final Color? backgroundColor;

  const FullScreenLoading({
    super.key,
    this.message,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 3.0,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            if (message != null) ...[
              const SizedBox(height: 16.0),
              Text(
                message!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Loading with logo or custom widget
class LoadingWithLogo extends StatelessWidget {
  final Widget? logo;
  final String? message;
  final Color? spinnerColor;

  const LoadingWithLogo({
    super.key,
    this.logo,
    this.message,
    this.spinnerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (logo != null) ...[
            logo!,
            const SizedBox(height: 24.0),
          ],
          CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              spinnerColor ?? Theme.of(context).primaryColor,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16.0),
            Text(
              message!,
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Shimmer loading widget for content placeholders
class ShimmerLoadingWidget extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const ShimmerLoadingWidget({
    super.key,
    this.width = double.infinity,
    this.height = 20.0,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius,
      ),
      child: const ShimmerEffect(),
    );
  }
}

class ShimmerEffect extends StatefulWidget {
  const ShimmerEffect({super.key});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: ShimmerPainter(_animation.value),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class ShimmerPainter extends CustomPainter {
  final double position;

  ShimmerPainter(this.position);

  @override
  void paint(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment(-1.0 + position, 0.0),
      end: Alignment(1.0 + position, 0.0),
      colors: [
        Colors.grey[300]!,
        Colors.grey[100]!,
        Colors.grey[300]!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant ShimmerPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

// Usage examples:
// 1. Basic loading: LoadingWidget()
// 2. With message: LoadingWidget(message: "Loading...", showMessage: true)
// 3. Custom size: LoadingWidget(size: 60, color: Colors.blue)
// 4. Full screen: FullScreenLoading(message: "Please wait...")
// 5. With logo: LoadingWithLogo(logo: Image.asset('assets/logo.png'))
// 6. Shimmer placeholder: ShimmerLoadingWidget(width: 200, height: 100)