import 'package:flutter/material.dart';

class StartupFailure extends StatelessWidget {
  const StartupFailure({
    super.key,
    required this.error,
    this.logPath,
    this.blocked = false,
  });

  final String error;
  final String? logPath;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF090909),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                const SizedBox(height: 16),
                Text(
                  blocked
                      ? "Windows is blocking Streak's data"
                      : 'Streak could not open its data',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  blocked
                      ? 'Nothing has been lost. This is usually Controlled folder '
                          'access. Open Windows Security > Virus & threat '
                          'protection > Manage ransomware protection > Allow an app '
                          'through Controlled folder access, add Streak.exe and '
                          'open Streak again.'
                      : 'Nothing has been lost. Please send this message to '
                          'github.com/InlitX/streak/issues so it can be fixed.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                if (logPath != null) ...[
                  const SizedBox(height: 20),
                  SelectableText(
                    'Details: $logPath',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
