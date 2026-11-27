import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';

/// Animated pulsing placeholder block used to compose loading skeletons.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppRadius.mdAll,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<Color?> _color = ColorTween(
    begin: AppColors.surfaceMuted,
    end: AppColors.border,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _color,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _color.value ?? AppColors.surfaceMuted,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}

/// Two-column skeleton grid matching the Home / Albums card layout.
class SkeletonMemoryGrid extends StatelessWidget {
  const SkeletonMemoryGrid({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: SkeletonBox(
            width: 120,
            height: 20,
            borderRadius: AppRadius.smAll,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (_, _) => const _SkeletonMemoryCard(),
        ),
      ],
    );
  }
}

class _SkeletonMemoryCard extends StatelessWidget {
  const _SkeletonMemoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SkeletonBox(
              width: double.infinity,
              borderRadius: BorderRadius.zero,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: 110,
                  height: 14,
                  borderRadius: AppRadius.smAll,
                ),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(
                  width: 72,
                  height: 12,
                  borderRadius: AppRadius.smAll,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical skeleton list matching list-tile pages (e.g. Recently Deleted).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
          boxShadow: AppShadows.card,
        ),
        child: const Row(
          children: [
            SkeletonBox(width: 56, height: 56, borderRadius: AppRadius.smAll),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 160,
                    height: 14,
                    borderRadius: AppRadius.smAll,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(
                    width: 100,
                    height: 12,
                    borderRadius: AppRadius.smAll,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal row of square photo skeletons for detail/strip loading states.
class SkeletonPhotoStrip extends StatelessWidget {
  const SkeletonPhotoStrip({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, _) => const SkeletonBox(
          width: 88,
          height: 88,
          borderRadius: AppRadius.mdAll,
        ),
      ),
    );
  }
}
