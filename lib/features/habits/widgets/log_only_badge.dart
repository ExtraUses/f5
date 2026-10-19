import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/app/theme/app_tokens.dart';
import 'package:streak/core/i18n/l10n.dart';

/// Small pill-shaped badge rendered next to log-only habits in the
/// main habit list and on the habit card.
///
/// Uses [LucideIcons.archive] as its icon — the same icon used by the
/// toggle in the editor — so users can visually connect the badge on
/// a card back to the toggle they flipped. The color is the surface's
/// "warning" token (an amber/orange) so it reads as "disabled from
/// analytics" without looking like a destructive alert.
class LogOnlyBadge extends StatelessWidget {
  const LogOnlyBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tint = context.tokens.warning;
    return Semantics(
      label: context.l10n.log_only,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: tint.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.archive,
              size: compact ? 10 : 12,
              color: tint,
            ),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                context.l10n.log_only,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: tint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
