import 'package:flutter/widgets.dart';

class KeepBuilt extends StatefulWidget {
  const KeepBuilt({super.key, required this.keys, required this.build});

  final List<Object?> keys;
  final Widget Function() build;

  @override
  State<KeepBuilt> createState() => _KeepBuiltState();
}

class _KeepBuiltState extends State<KeepBuilt> {
  List<Object?> _keys = const [];
  Widget? _child;

  @override
  Widget build(BuildContext context) {
    final keys = widget.keys;
    if (_child == null || !_same(keys, _keys)) {
      _keys = keys;
      _child = widget.build();
    }
    return _child!;
  }

  static bool _same(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i]) && a[i] != b[i]) return false;
    }
    return true;
  }
}
