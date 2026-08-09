import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/auth_models.dart';
import '../data/auth_provider.dart';

class UnclaimedDataScreen extends ConsumerWidget {
  const UnclaimedDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final count = auth.asData?.value.queueSummary.unclaimedCount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.manage_history,
                    color: AppColors.purple400,
                    size: 64,
                  ),
                  Spacing.verticalXxl,
                  Text(
                    'Usage recorded before sign-in',
                    style: AppTextStyles.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  Spacing.verticalMd,
                  Text(
                    '$count queued ${count == 1 ? 'item was' : 'items were'} recorded without an account. Import them into this account, or discard them. Nothing uploads until you choose.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Spacing.verticalXxl,
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .resolveUnclaimedData(
                                  UnclaimedDataDecision.import,
                                ),
                      label: 'Import into this account',
                    ),
                  ),
                  Spacing.verticalMd,
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .resolveUnclaimedData(
                                  UnclaimedDataDecision.discard,
                                ),
                      label: 'Discard unclaimed data',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
