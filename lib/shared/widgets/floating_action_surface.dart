import 'package:flutter/material.dart';

class FloatingActionSurface extends StatelessWidget {
  const FloatingActionSurface({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 14,
    this.minHeight = 58,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
      elevation: 0,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.06),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                offset: const Offset(0, 8),
                blurRadius: 14,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
