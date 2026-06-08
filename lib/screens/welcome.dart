import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/theme/app_theme_extensions.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tawheed.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.85)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Sharah\n Kitab al-Tawheed',
                        textAlign: TextAlign.center,
                        style: context.textTheme.displayLarge?.copyWith(
                          color: semantic.onScrim,
                          fontSize: 38,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'شرح کتاب التوحید',
                        textAlign: TextAlign.center,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontSize: 30,
                          color: context.brandColor,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'By Shaikh Abdullah Nasir Rahmani Hafizahullah',
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: semantic.onScrimMuted,
                          height: 1.5,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: context.textTheme.labelLarge
                            ?.copyWith(color: semantic.onBrand),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        Icons.headphones_rounded,
                        size: 22,
                        color: semantic.onBrand,
                      ),
                      label: Text(
                        'START LISTENING',
                        style: TextStyle(color: semantic.onBrand),
                      ),
                      onPressed: () => context.go('/lectures'),
                    ),
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
