import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../shared/models/models.dart';

/// Provider for accountability partners.
final partnersProvider =
    NotifierProvider<PartnersNotifier, List<AccountabilityPartner>>(
  PartnersNotifier.new,
);

class PartnersNotifier extends Notifier<List<AccountabilityPartner>> {
  @override
  List<AccountabilityPartner> build() => const [
    AccountabilityPartner(
      id: '1',
      name: 'John Doe',
      email: 'john@example.com',
    ),
  ];

  void addPartner(String email) {
    final name = email.split('@').first;
    state = [
      ...state,
      AccountabilityPartner(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: email,
      ),
    ];
  }

  void removePartner(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

/// Accountability setup screen.
class AccountabilityScreen extends ConsumerStatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  ConsumerState<AccountabilityScreen> createState() =>
      _AccountabilityScreenState();
}

class _AccountabilityScreenState extends ConsumerState<AccountabilityScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addPartner() {
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

    ref.read(partnersProvider.notifier).addPartner(email);
    _emailController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Accountability partner added!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partners = ref.watch(partnersProvider);

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
                title: 'Accountability',
                subtitle: 'Share your progress with others',
                onBack: () => context.pop(),
                label: 'HLR-5',
              ),
              Spacing.verticalXxl,

              // Info Card
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

              // Add Partner Section
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
                          onPressed: _addPartner,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Icon(Icons.person_add, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Spacing.verticalXxl,

              // Active Partners
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

              ...partners.map((partner) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PartnerCard(
                      partner: partner,
                      onRemove: () {
                        ref.read(partnersProvider.notifier).removePartner(partner.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Partner removed'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  )),
              Spacing.verticalXxl,

              // What They'll See
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

              // Privacy Note
              const InfoCard(
                message: 'Only summary data is shared. Your detailed app usage remains private.',
                icon: '🔒',
                type: InfoCardType.info,
              ),
              Spacing.verticalLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.partner,
    required this.onRemove,
  });

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
