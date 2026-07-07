import 'package:flutter/material.dart';

import '../../core/accessibility/questra_accessibility.dart';
import '../../core/theme/questra_colors.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';

class QuestraArcFloatingEntry extends StatelessWidget {
  const QuestraArcFloatingEntry({
    required this.onPressed,
    this.extended = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final label = extended ? 'Arcへ相談' : 'Arcへ';

    return Semantics(
      button: true,
      label: 'Arcを開く',
      child: ExcludeSemantics(
        child: Tooltip(
          message: 'Arcを開く',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('questra-arc-floating-entry'),
              borderRadius: BorderRadius.circular(999),
              onTap: onPressed,
              child: ConstrainedBox(
                constraints: QuestraAccessibility.minTapTargetConstraints,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: QuestraColors.deepNavy.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: QuestraColors.gold.withValues(alpha: 0.46),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: QuestraColors.gold.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      right: extended ? 14 : 10,
                      top: 7,
                      bottom: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: QuestraColors.white.withValues(alpha: 0.08),
                            border: Border.all(color: QuestraColors.gold),
                          ),
                          child: const ArcWidget(
                            emotion: ArcEmotion.normal,
                            size: 28,
                            showSpeechBubble: false,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: QuestraColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
