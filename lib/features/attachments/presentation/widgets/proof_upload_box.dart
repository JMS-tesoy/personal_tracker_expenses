import 'package:flutter/material.dart';

class ProofUploadBox extends StatelessWidget {
  const ProofUploadBox({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: colors.outlineVariant,
          width: 1.5,
          style: BorderStyle.none,
        ),
        borderRadius: BorderRadius.circular(12),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.upload_file_outlined,
              size: 40, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Upload payment proof',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Screenshot/photo support will be added next.',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}