import 'package:flutter/material.dart';
import 'package:streak/app/theme/app_theme.dart';

extension InkOn on Color {
  Color get ink => computeLuminance() > 0.55 ? Colors.black : Colors.white;

  Color shownIn(BuildContext context) => AppTheme.adaptAccent(
        this,
        Theme.of(context).brightness == Brightness.dark,
      );
}
