import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/torrent_notifier.dart';

class FilterSegmentedControl extends StatelessWidget {
  const FilterSegmentedControl({
    super.key,
    required this.activeFilter,
    required this.onChanged,
  });

  final TorrentFilter activeFilter;
  final ValueChanged<TorrentFilter> onChanged;

  int get _activeIndex {
    switch (activeFilter) {
      case TorrentFilter.all:
        return 0;
      case TorrentFilter.downloading:
        return 1;
      case TorrentFilter.completed:
        return 2;
    }
  }

  static const _labels = ['All', 'Downloading', 'Completed'];
  static const _filters = [
    TorrentFilter.all,
    TorrentFilter.downloading,
    TorrentFilter.completed,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final pillWidth = totalWidth / 3;
        const pillInset = 3.0;

        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ── Sliding pill with elastic spring ─────────────────────────
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _activeIndex * pillWidth + pillInset,
                top: pillInset,
                bottom: pillInset,
                width: pillWidth - pillInset * 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.downloading,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.downloading.withValues(alpha: 0.38),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Label row with spring-scale tap ──────────────────────────
              Row(
                children: List.generate(3, (i) {
                  final isActive = i == _activeIndex;
                  return Expanded(
                    child: _SpringTapTarget(
                      onTap: () => onChanged(_filters[i]),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style:
                              (Theme.of(context).textTheme.labelLarge ??
                                      const TextStyle())
                                  .copyWith(
                                    color: isActive
                                        ? Colors.white
                                        : AppColors.textSecondary(context),
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    letterSpacing: isActive ? -0.1 : 0,
                                  ),
                          child: Text(_labels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A tap target that animates a spring-scale press effect on its child.
class _SpringTapTarget extends StatefulWidget {
  const _SpringTapTarget({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_SpringTapTarget> createState() => _SpringTapTargetState();
}

class _SpringTapTargetState extends State<_SpringTapTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTapDown(TapDownDetails _) async {
    await _controller.forward();
  }

  Future<void> _onTapUp(TapUpDetails _) async {
    await _controller.reverse();
    widget.onTap();
  }

  Future<void> _onTapCancel() async {
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
