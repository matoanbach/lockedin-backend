import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';

/// First onboarding screen - Welcome and feature highlights.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Column(
            children: [
              // HLR Label
              Align(
                alignment: Alignment.centerRight,
                child: Text('HLR-6', style: AppTextStyles.labelSmall),
              ),

              // Main Content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    _buildLogo(),
                    Spacing.verticalXxl,

                    // App Name & Tagline
                    _buildTitle(),
                    Spacing.verticalXxl,
                    Spacing.verticalLg,

                    // Feature Highlights
                    _buildFeatureList(),
                  ],
                ),
              ),

              // CTA Button
              PrimaryButton(
                onPressed: () => context.push(AppRoutes.onboardingPermissions),
                label: 'Get Started',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main logo container
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.purple600, AppColors.purple400],
            ),
            borderRadius: Spacing.borderRadiusXxl,
            boxShadow: [
              BoxShadow(
                color: AppColors.purple500.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.lock_outline, size: 48, color: Colors.white),
          ),
        ),
        // Target badge
        Positioned(
          top: -8,
          right: -8,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.purple500,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.track_changes, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.purple400, Colors.white],
          ).createShader(bounds),
          child: Text(
            'LockdIn',
            style: AppTextStyles.displayLarge.copyWith(color: Colors.white),
          ),
        ),
        Spacing.verticalSm,
        Text(
          'Take control of your screen time',
          style: AppTextStyles.titleLarge.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
    final features = [
      (Icons.lock_outline, 'Smart Lockdown', 'Block apps when limits hit'),
      (Icons.bar_chart, 'Deep Insights', 'Track patterns & trends'),
      (Icons.shield_outlined, 'Stay Accountable', 'Share progress with others'),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _FeatureCard(
            icon: feature.$1,
            title: feature.$2,
            subtitle: feature.$3,
          ),
        );
      }).toList(),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          IconBox(
            icon: icon,
            size: 40,
            iconSize: 20,
            color: AppColors.purple400,
          ),
          Spacing.horizontalLg,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Spacing.verticalXs,
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
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
