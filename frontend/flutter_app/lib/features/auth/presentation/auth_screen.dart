import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/auth_models.dart';
import '../data/auth_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final authState = auth.asData?.value;
    final needsRenewal = authState?.phase == AuthPhase.reauthenticationRequired;
    final hasKnownAccount = authState?.hasKnownAccount ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: AppColors.purple400,
                    size: 64,
                  ),
                  Spacing.verticalXxl,
                  Text(
                    needsRenewal ? 'Sign in again' : 'Welcome to LockdIn',
                    style: AppTextStyles.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  Spacing.verticalMd,
                  Text(
                    needsRenewal
                        ? authState?.message ??
                              'Your session needs to be renewed.'
                        : hasKnownAccount
                        ? 'Sign in with the account already used on this device.'
                        : 'Sign in or create an account securely in your system browser.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (authState?.message != null && !needsRenewal) ...[
                    Spacing.verticalLg,
                    Text(
                      authState!.message!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.redAccent,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  Spacing.verticalXxl,
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      onPressed: auth.isLoading
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .signIn(),
                      label: auth.isLoading
                          ? 'Opening secure browser…'
                          : needsRenewal
                          ? 'Continue to sign in'
                          : 'Sign in',
                    ),
                  ),
                  if (!needsRenewal && !hasKnownAccount) ...[
                    Spacing.verticalMd,
                    SizedBox(
                      width: double.infinity,
                      child: SecondaryButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signIn(createAccount: true),
                        label: 'Create account',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
