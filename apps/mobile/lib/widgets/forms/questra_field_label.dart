import 'package:flutter/material.dart';

/// Keeps field names outside the input border so labels never collide with text.
class QuestraFieldLabel extends StatelessWidget {
  const QuestraFieldLabel({
    required this.label,
    required this.child,
    this.helper,
    this.required = false,
    this.foregroundColor,
    super.key,
  });

  final String label;
  final String? helper;
  final bool required;
  final Color? foregroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: foregroundColor,
                    ),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 6),
              Text(
                '必須',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ],
        ),
        if (helper != null) ...[
          const SizedBox(height: 3),
          Text(
            helper!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foregroundColor?.withValues(alpha: 0.72) ??
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
