import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

typedef MorphMenuItem = ({IconData icon, String label, VoidCallback onTap});

class MorphMenuStyle {
  const MorphMenuStyle({
    required this.closed,
    required this.open,
    required this.edge,
    required this.ink,
    required this.tile,
    required this.barrier,
    this.blur = 22,
  });

  factory MorphMenuStyle.glass() => MorphMenuStyle(
        closed: const Color(0xFF2A2A2F).withValues(alpha: 0.5),
        open: const Color(0xFF2A2A2F).withValues(alpha: 0.9),
        edge: Colors.white.withValues(alpha: 0.12),
        ink: Colors.white,
        tile: Colors.white.withValues(alpha: 0.1),
        barrier: Colors.black.withValues(alpha: 0.25),
      );

  factory MorphMenuStyle.paper(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MorphMenuStyle(
      closed: Colors.transparent,
      open: scheme.surface,
      edge: scheme.outlineVariant,
      ink: scheme.onSurface,
      tile: scheme.onSurface.withValues(alpha: 0.06),
      barrier: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
      blur: 0,
    );
  }

  final Color closed;
  final Color open;
  final Color edge;
  final Color ink;
  final Color tile;
  final Color barrier;
  final double blur;
}

class MorphMenu extends StatefulWidget {
  const MorphMenu({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.items,
    required this.style,
    this.anchor = Alignment.topRight,
  });

  final IconData icon;
  final String tooltip;
  final List<MorphMenuItem> items;
  final MorphMenuStyle style;
  final Alignment anchor;

  @override
  State<MorphMenu> createState() => _MorphMenuState();
}

class _MorphMenuState extends State<MorphMenu>
    with SingleTickerProviderStateMixin {
  static const _button = 44.0;
  static const _width = 236.0;
  static const _row = 48.0;
  static const _pad = 8.0;

  late final AnimationController _controller;
  final _portal = OverlayPortalController();
  final _link = LayerLink();
  bool _open = false;

  double get _height => widget.items.length * _row + _pad * 2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _show() {
    setState(() => _open = true);
    _portal.show();
    _controller.forward();
  }

  Future<void> _hide() async {
    if (!_open) return;
    setState(() => _open = false);
    await _controller.reverse();
    if (mounted && !_open) setState(_portal.hide);
  }

  void _pick(VoidCallback action) {
    _hide();
    action();
  }

  static double _span(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  Widget _panel(BuildContext context) {
    final style = widget.style;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.ease.transform(_controller.value);
        final wide = Curves.easeOutCubic.transform(_span(t, 0.1, 1));
        final tall = Curves.easeOutCubic.transform(_span(t, 0.3, 1));
        final squeeze = 1 - 0.08 * math.sin(math.pi * _span(t, 0, 0.6));
        final width = lerpDouble(_button, _width, wide)!;
        final height = lerpDouble(_button, _height, tall)!;
        final radius = lerpDouble(_button / 2, 26, wide)!;
        final glyph = 1 - _span(t, 0, 0.35);

        return Transform.scale(
          scale: squeeze,
          alignment: widget.anchor,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: style.blur * (0.6 + 0.4 * wide),
                  sigmaY: style.blur * (0.6 + 0.4 * wide),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(style.closed, style.open, wide),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: style.edge),
                  ),
                  child: Stack(
                    children: [
                      if (glyph > 0)
                        Positioned(
                          top: 0,
                          left: widget.anchor.x < 0 ? 0 : null,
                          right: widget.anchor.x < 0 ? null : 0,
                          width: _button,
                          height: _button,
                          child: Opacity(
                            opacity: glyph,
                            child: Icon(
                              widget.icon,
                              size: 19,
                              color: style.ink,
                            ),
                          ),
                        ),
                      OverflowBox(
                        alignment: widget.anchor,
                        minWidth: _width,
                        maxWidth: _width,
                        minHeight: _height,
                        maxHeight: _height,
                        child: Padding(
                          padding: const EdgeInsets.all(_pad),
                          child: Column(
                            children: [
                              for (final (index, item) in widget.items.indexed)
                                _item(item, _span(t, 0.4 + index * 0.06,
                                    math.min(0.7 + index * 0.06, 1))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _item(MorphMenuItem item, double shown) {
    final settle = Curves.easeOutBack.transform(shown);
    return Opacity(
      opacity: Curves.easeOut.transform(shown),
      child: Transform.translate(
        offset: Offset(0, -14 * (1 - settle)),
        child: Transform.scale(
          scale: 0.7 + 0.3 * settle,
          child: IgnorePointer(
            ignoring: shown < 1,
            child: SizedBox(
              height: _row,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _pick(item.onTap),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: widget.style.tile,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            size: 16,
                            color: widget.style.ink,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: widget.style.ink,
                            ),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hide();
      },
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hide,
                child: FadeTransition(
                  opacity: _controller,
                  child: ColoredBox(
                    color: widget.style.barrier,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: _link,
                targetAnchor: widget.anchor,
                followerAnchor: widget.anchor,
                child: _panel(context),
              ),
            ),
          ],
        ),
        child: CompositedTransformTarget(
          link: _link,
          child: Opacity(
            opacity: _portal.isShowing ? 0 : 1,
            child: MorphMenuButton(
              icon: widget.icon,
              tooltip: widget.tooltip,
              style: widget.style,
              onTap: _show,
            ),
          ),
        ),
      ),
    );
  }
}

class MorphMenuButton extends StatelessWidget {
  const MorphMenuButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.style,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final MorphMenuStyle style;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _MorphMenuState._button,
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: ClipOval(
              child: BackdropFilter(
                enabled: style.blur > 0,
                filter: ImageFilter.blur(
                  sigmaX: style.blur * 0.6,
                  sigmaY: style.blur * 0.6,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? style.ink : style.closed,
                    border: Border.all(color: active ? style.ink : style.edge),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: active ? Theme.of(context).colorScheme.surface : style.ink,
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
