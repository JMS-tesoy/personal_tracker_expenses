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
  });

  final String title;
  final String value;
  final IconData icon;
  final bool isLarge;
  final String? subtitle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
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
            Row(
              children: [
                Container(
                  width: isLarge ? 46 : 38,
                  height: isLarge ? 46 : 38,
                  decoration: BoxDecoration(
                    color: isLarge
                        ? colorScheme.surface.withValues(alpha: 0.76)
                        : colorScheme.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: isLarge ? colorScheme.primary : colorScheme.primary,
                    size: isLarge ? 24 : 20,
                  ),
                ),
                const Spacer(),
              ],
            ),
            SizedBox(height: isLarge ? 22 : 14),
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
          ],
        ),
      ),
    );
  }
}
