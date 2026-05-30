import 'package:flutter/material.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/theme/app_colors.dart';

class ChapterHeader extends StatelessWidget {
  final Chapter chapter;

  const ChapterHeader({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            chapter.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Text(
            '${chapter.lectureCount} ${chapter.lectureCount == 1 ? 'part' : 'parts'}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
