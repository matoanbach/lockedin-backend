import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../data/accountability_provider.dart';

/// Accountability setup screen.
class AccountabilityScreen extends ConsumerStatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  ConsumerState<AccountabilityScreen> createState() =>
      _AccountabilityScreenState();
}

class _AccountabilityScreenState extends ConsumerState<AccountabilityScreen> {
  final _emailController = TextEditingController();
  bool _isAddingPartner = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addPartner() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAddingPartner = true);

    try {
      await ref.read(accountabilityPartnersProvider.notifier).addPartner(email);
      _emailController.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accountability partner added!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeApiError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isAddingPartner = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(accountabilityPartnersProvider);

    return partnersAsync.when(
      data: (partners) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: Spacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  title: 'Accountability',
                  subtitle: 'Share your progress with others',
                  onBack: () => context.pop(),
                  label: 'HLR-5',
                ),
                Spacing.verticalXxl,
                GradientCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBox(
                        icon: Icons.people_outline,
                        size: 48,
                        iconSize: 24,
                        color: AppColors.purple400,
                      ),
                      Spacing.horizontalLg,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stay on Track Together',
                              style: AppTextStyles.titleMedium,
                            ),
                            Spacing.verticalXs,
                            Text(
                              'Your accountability partners will receive notifications when you exceed your limits.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Spacing.verticalXxl,
                Text(
                  'Add Contact',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Spacing.verticalMd,
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email Address',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      Spacing.verticalSm,
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _emailController,
                              style: AppTextStyles.bodyMedium,
                              decoration: InputDecoration(
                                hintText: 'partner@example.com',
                                hintStyle: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          Spacing.horizontalSm,
                          ElevatedButton(
                            onPressed: _isAddingPartner ? null : _addPartner,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.all(12),
                              minimumSize: const Size(48, 48),
                            ),
                            child: _isAddingPartner
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.person_add, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Spacing.verticalXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Partners',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${partners.length}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Spacing.verticalMd,
                if (partners.isEmpty)
                  const InfoCard(
                    message:
                        'No accountability contacts saved yet. Add one above to persist it to the backend.',
                    icon: 'i',
                    type: InfoCardType.info,
                  ),
                ...partners.map(
                  (partner) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PartnerCard(
                      partner: partner,
                      onRemove: () async {
                        try {
                          await ref
                              .read(accountabilityPartnersProvider.notifier)
                              .removePartner(partner.id);

                          if (!mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Partner removed'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (error) {
                          if (!mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(describeApiError(error)),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                Spacing.verticalXxl,
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What they\'ll see',
                        style: AppTextStyles.titleMedium,
                      ),
                      Spacing.verticalMd,
                      _BulletPoint('When you exceed daily limits'),
                      _BulletPoint('Weekly progress summaries'),
                      _BulletPoint('Achievements and milestones'),
                    ],
                  ),
                ),
                Spacing.verticalXxl,
                const InfoCard(
                  message:
                      'Only summary data is shared. Your detailed app usage remains private.',
                  icon: '🔒',
                  type: InfoCardType.info,
                ),
                Spacing.verticalLg,
              ],
            ),
          ),
        ),
      ),
      loading: () => const _AccountabilityLoadingState(),
      error: (error, _) => _AccountabilityLoadingState(
        errorMessage: describeApiError(error),
        onRetry: () {
          ref.read(accountabilityPartnersProvider.notifier).refresh();
        },
      ),
    );
  }
}

class _AccountabilityLoadingState extends StatelessWidget {
  const _AccountabilityLoadingState({this.errorMessage, this.onRetry});

  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hasError)
                  const CircularProgressIndicator(color: AppColors.purple400),
                if (hasError)
                  const Icon(Icons.cloud_off, color: AppColors.error, size: 36),
                Spacing.verticalLg,
                Text(
                  hasError
                      ? 'Could not load accountability contacts'
                      : 'Loading accountability contacts',
                  style: AppTextStyles.titleLarge,
                ),
                Spacing.verticalSm,
                Text(
                  errorMessage ??
                      'Fetching your saved accountability partners.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (hasError && onRetry != null) ...[
                  Spacing.verticalXxl,
                  SizedBox(
                    width: 160,
                    child: SecondaryButton(onPressed: onRetry, label: 'Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.onRemove});

  final AccountabilityPartner partner;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleIconBox(
            icon: Icons.person,
            size: 40,
            iconSize: 20,
            color: AppColors.purple400,
          ),
          Spacing.horizontalMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner.name, style: AppTextStyles.titleSmall),
                Spacing.verticalXs,
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    Spacing.horizontalXs,
                    Text(
                      partner.email,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.error,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.purple400,
              shape: BoxShape.circle,
            ),
          ),
          Spacing.horizontalSm,
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
