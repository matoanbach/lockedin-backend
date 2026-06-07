import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';

/// Privacy policy screen.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: Spacing.page,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ScreenHeader(
                title: 'Privacy & Legal',
                subtitle: 'How we protect your data',
                onBack: () => context.pop(),
                label: 'HLR-16-18',
              ),
              Spacing.verticalXxl,

              // Key Points Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: const [
                  _KeyPointCard(icon: Icons.shield_outlined, label: '100% Private'),
                  _KeyPointCard(icon: Icons.lock_outline, label: 'On-Device'),
                  _KeyPointCard(icon: Icons.visibility_off_outlined, label: 'No Tracking'),
                  _KeyPointCard(icon: Icons.description_outlined, label: 'Open Source'),
                ],
              ),
              Spacing.verticalXxl,

              // Privacy Policy Content
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: Spacing.card,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text('Privacy Policy', style: AppTextStyles.titleMedium),
                    ),
                    SizedBox(
                      height: 400,
                      child: SingleChildScrollView(
                        padding: Spacing.card,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PolicySection(
                              title: '1. Data Collection',
                              content:
                                  'LockdIn collects app usage statistics solely for the purpose of tracking your screen time. When Android usage sync is enabled, session summaries are transmitted to your configured LockdIn backend so analytics can be calculated consistently across the app.',
                            ),
                            _PolicySection(
                              title: '2. Data Storage',
                              content:
                                  'Your preferences are stored in the LockdIn backend you connect to. Usage sessions collected from Android are synced to that backend as well. We do not share that data with third parties.',
                            ),
                            _PolicySection(
                              title: '3. Permissions',
                              content:
                                  'LockdIn requires the following permissions:',
                              bulletPoints: const [
                                'Usage Access: To monitor app usage times',
                                'Notifications: To send limit alerts',
                                'Accessibility: To enforce app blocking',
                              ],
                            ),
                            _PolicySection(
                              title: '4. Third-Party Sharing',
                              content:
                                  'We do not share, sell, or transmit your data to any third parties. The accountability feature only shares summary statistics that you explicitly choose to share.',
                            ),
                            _PolicySection(
                              title: '5. WCAG Compliance',
                              content:
                                  'LockdIn is designed to meet WCAG 2.1 Level AA standards for accessibility, ensuring the app is usable by everyone, including users with disabilities.',
                            ),
                            _PolicySection(
                              title: '6. Contact',
                              content:
                                  'For privacy concerns or questions, contact us at privacy@lockdin.app',
                            ),
                            Spacing.verticalLg,
                            Text(
                              'Last updated: October 22, 2025',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Spacing.verticalXxl,

              // Acceptance Card
              const InfoCard(
                message: 'You\'ve accepted our privacy policy',
                icon: '✓',
                type: InfoCardType.success,
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyPointCard extends StatelessWidget {
  const _KeyPointCard({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.purple400, size: 24),
          Spacing.verticalSm,
          Text(
            label,
            style: AppTextStyles.labelLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.content,
    this.bulletPoints,
  });

  final String title;
  final String content;
  final List<String>? bulletPoints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleSmall,
        ),
        Spacing.verticalSm,
        Text(
          content,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        if (bulletPoints != null) ...[
          Spacing.verticalSm,
          ...bulletPoints!.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.purple400,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        point,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
        Spacing.verticalLg,
        Divider(color: AppColors.border, height: 1),
        Spacing.verticalLg,
      ],
    );
  }
}
