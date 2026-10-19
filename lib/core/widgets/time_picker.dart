import 'package:flutter/material.dart';

Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) =>
    showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            dialogTheme: theme.dialogTheme.copyWith(
              constraints: const BoxConstraints(minWidth: 280),
            ),
          ),
          child: child!,
        );
      },
    );
