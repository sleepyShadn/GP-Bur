import 'package:flutter/material.dart';

/// Skeleton shimmer for [AllGoalsAndActivitiesPage] — matches goal card layout.
class AllGoalsShimmer extends StatefulWidget {
  const AllGoalsShimmer({super.key, this.cardCount = 3});

  final int cardCount;

  @override
  State<AllGoalsShimmer> createState() => _AllGoalsShimmerState();
}

class _AllGoalsShimmerState extends State<AllGoalsShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color _base = Color(0xFFE8F0E0);
  static const Color _highlight = Color(0xFFF8FBF5);
  static const Color _accent = Color(0xFFD4E4C8);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: widget.cardCount,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == widget.cardCount - 1 ? 0 : 18),
          child: _GoalCardSkeleton(controller: _controller),
        );
      },
    );
  }
}

class _GoalCardSkeleton extends StatelessWidget {
  const _GoalCardSkeleton({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFC1CFA1).withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xff7f9461).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _ShimmerBox(
                  controller: controller,
                  width: 88,
                  height: 14,
                  borderRadius: 8,
                  base: _AllGoalsShimmerState._accent,
                ),
                const Spacer(),
                _ShimmerBox(
                  controller: controller,
                  width: 72,
                  height: 22,
                  borderRadius: 12,
                  base: _AllGoalsShimmerState._base,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _ShimmerBox(
                  controller: controller,
                  width: 44,
                  height: 44,
                  borderRadius: 14,
                  base: const Color(0xFFC1CFA1).withValues(alpha: 0.55),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ShimmerBox(
                        controller: controller,
                        width: 72,
                        height: 11,
                        borderRadius: 6,
                        base: _AllGoalsShimmerState._accent,
                      ),
                      const SizedBox(height: 8),
                      _ShimmerBox(
                        controller: controller,
                        height: 14,
                        borderRadius: 8,
                        base: _AllGoalsShimmerState._base,
                      ),
                      const SizedBox(height: 6),
                      _ShimmerBox(
                        controller: controller,
                        width: double.infinity,
                        height: 14,
                        borderRadius: 8,
                        base: _AllGoalsShimmerState._base,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ShimmerBox(
              controller: controller,
              width: 140,
              height: 16,
              borderRadius: 8,
              base: const Color(0xff7f9461).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            ...List<Widget>.generate(3, (int i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i == 2 ? 0 : 10),
                child: Row(
                  children: <Widget>[
                    _ShimmerBox(
                      controller: controller,
                      width: 22,
                      height: 22,
                      borderRadius: 6,
                      base: _AllGoalsShimmerState._accent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ShimmerBox(
                        controller: controller,
                        height: 12,
                        borderRadius: 6,
                        base: _AllGoalsShimmerState._base,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ShimmerBox(
                      controller: controller,
                      width: 36,
                      height: 22,
                      borderRadius: 10,
                      base: _AllGoalsShimmerState._accent,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.controller,
    required this.height,
    required this.borderRadius,
    required this.base,
    this.width,
  });

  final AnimationController controller;
  final double? width;
  final double height;
  final double borderRadius;
  final Color base;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? child) {
          final double t = controller.value;
          final double beginX = -1.4 + (2.8 * t);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment(beginX, 0),
                end: Alignment(beginX + 1.0, 0),
                colors: <Color>[
                  base.withValues(alpha: 0.55),
                  _AllGoalsShimmerState._highlight,
                  base.withValues(alpha: 0.55),
                ],
                stops: const <double>[0.15, 0.5, 0.85],
              ),
            ),
          );
        },
      ),
    );
  }
}
