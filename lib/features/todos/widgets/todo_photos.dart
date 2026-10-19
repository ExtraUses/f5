import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:streak/core/i18n/l10n.dart';
import 'package:streak/core/widgets/cover_image.dart';

class TodoPhotoGrid extends StatelessWidget {
  const TodoPhotoGrid({super.key, required this.paths, this.onRemove});

  final List<String> paths;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final (index, path) in paths.indexed)
        if (CoverImage.exists(path)) (index, path),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    if (shown.length == 1) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: _Tile(
            path: shown.single.$2,
            onTap: () => showTodoPhotos(context, paths, shown.single.$1),
            onRemove: onRemove == null ? null : () => onRemove!(shown.single.$1),
          ),
        ),
      );
    }
    final rows = [
      for (var i = 0; i < shown.length; i += 3)
        shown.sublist(i, (i + 3).clamp(0, shown.length)),
    ];
    return Column(
      children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (final (i, entry) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: row.length == 2 ? 1.2 : 1,
                    child: _Tile(
                      path: entry.$2,
                      onTap: () => showTodoPhotos(context, paths, entry.$1),
                      onRemove:
                          onRemove == null ? null : () => onRemove!(entry.$1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.path, required this.onTap, this.onRemove});

  final String path;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CoverImage(path: path),
          ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: Semantics(
                button: true,
                label: context.l10n.delete,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showTodoPhotos(
  BuildContext context,
  List<String> paths,
  int start,
) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).closeButtonLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => _PhotoViewer(paths: paths, start: start),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return AnimatedBuilder(
          animation: curved,
          child: child,
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.86 * curved.value),
              ),
              Opacity(
                opacity: curved.value,
                child: Transform.scale(
                  scale: 0.9 + 0.1 * curved.value,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.paths, required this.start});

  final List<String> paths;
  final int start;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.start);
  late int _index = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final many = widget.paths.length > 1;
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          PageView.builder(
            controller: _pages,
            itemCount: widget.paths.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.fromLTRB(22, 64, 22, 72),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.file(
                      File(widget.paths[index]),
                      fit: BoxFit.contain,
                      cacheWidth: (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context) *
                              2)
                          .round(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 12,
            child: _Round(
              icon: LucideIcons.x,
              label: MaterialLocalizations.of(context).closeButtonLabel,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          if (many)
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.paths.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: i == _index ? 0.95 : 0.45,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
