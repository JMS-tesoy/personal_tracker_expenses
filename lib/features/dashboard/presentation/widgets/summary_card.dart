import 'package:flutter/material.dart';

class DashboardSummaryCard extends StatelessWidget {
  const DashboardSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.isLarge = false,
    this.subtitle,
    this.valueColor,
    this.actionIcon,
    this.onActionPressed,
    this.actionTooltip,
  });

  final String title;
  final String value;
  final IconData icon;
  final bool isLarge;
  final String? subtitle;
  final Color? valueColor;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;
  final String? actionTooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isLarge ? 10 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.32),
      surfaceTintColor: Colors.transparent,
      color: isLarge
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isLarge
              ? colorScheme.outline.withValues(alpha: 0.62)
              : colorScheme.outlineVariant.withValues(alpha: 0.9),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLarge ? 22 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isLarge) ...[
              Row(
                children: [
                  _SummaryIcon(icon: icon, isLarge: isLarge),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLarge
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style:
                  (isLarge
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                        color:
                            valueColor ??
                            (isLarge
                                ? colorScheme.onSurface
                                : colorScheme.onSurface),
                        fontWeight: FontWeight.w800,
                      ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isLarge
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (isLarge) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  _SummaryIcon(icon: icon, isLarge: isLarge),
                  const Spacer(),
                  if (actionIcon != null && onActionPressed != null)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: IconButton(
                        onPressed: onActionPressed,
                        padding: EdgeInsets.zero,
                        tooltip: actionTooltip,
                        icon: Icon(
                          actionIcon,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryIcon extends StatelessWidget {
  const _SummaryIcon({required this.icon, required this.isLarge});

  final IconData icon;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: isLarge ? 46 : 38,
      height: isLarge ? 46 : 38,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: isLarge ? 0.76 : 0.78),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: colorScheme.primary, size: isLarge ? 24 : 20),
    );
  }
}
