import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_error.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../preferences/data/preferences_provider.dart';

class AppBootstrapScreen extends ConsumerWidget {
  const AppBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesControllerProvider);

    return preferences.when(
      data: (value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }

          context.go(
            value.hasCompletedOnboarding
                ? AppRoutes.dashboard
                : AppRoutes.onboardingWelcome,
          );
        });

        return const _BootstrapScaffold(
          title: 'Loading your profile',
          message: 'Syncing your LockdIn settings from the backend.',
          isLoading: true,
        );
      },
      loading: () => const _BootstrapScaffold(
        title: 'Connecting to LockdIn',
        message: 'Starting the app and reaching your local backend.',
        isLoading: true,
      ),
      error: (error, _) => _BootstrapScaffold(
        title: 'Backend unavailable',
        message: describeApiError(error),
        isLoading: false,
        action: SecondaryButton(
          onPressed: () {
            ref.read(preferencesControllerProvider.notifier).refresh();
          },
          label: 'Retry',
        ),
      ),
    );
  }
}

class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold({
    required this.title,
    required this.message,
    required this.isLoading,
    this.action,
  });

  final String title;
  final String message;
  final bool isLoading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: Spacing.page,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.purple600, AppColors.purple400],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.cloud_off,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
                Spacing.verticalXxl,
                Text(title, style: AppTextStyles.headlineLarge),
                Spacing.verticalMd,
                Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[
                  Spacing.verticalXxl,
                  SizedBox(width: 180, child: action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
