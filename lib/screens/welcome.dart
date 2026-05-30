import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/theme/app_colors.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/tawheed.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark overlay — suits the dark theme aesthetic
          Container(color: const Color(0xCC1C1C1E)),
          // Content
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Sharah Kitab\nal-Tawheed',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'شرح کتاب التوحید',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'By Fazilat Shaikh Abdullah Nasir Rahmani Hafizahullah',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // CTA button
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.headphones_rounded, size: 22),
                      label: const Text('START LISTENING'),
                      onPressed: () =>
                          context.go('/lectures'),
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
