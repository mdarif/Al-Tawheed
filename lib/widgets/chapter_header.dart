import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/models/catalog.dart';
import 'package:myapp/providers/language_provider.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

class ChapterHeader extends StatelessWidget {
  final Chapter chapter;

  const ChapterHeader({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: context.brandColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            context.read<LanguageProvider>().resolve(chapter.title),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '${chapter.lectureCount} ${chapter.lectureCount == 1 ? 'part' : 'parts'}',
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
