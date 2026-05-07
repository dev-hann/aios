import 'package:aios/core/theme/app_colors.dart';
import 'package:aios/presentation/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = <Widget>[
    _WelcomePage(),
    _ModelSetupPage(),
    _PermissionPage(),
    _ReadyPage(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finish() {
    ref.read(settingsProvider.notifier).completeOnboarding();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            _PageIndicator(
              count: _pages.length,
              current: _currentPage,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _currentPage < _pages.length - 1 ? _nextPage : _finish,
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Get Started',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          return Container(
            width: i == current ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.divider,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          );
        }),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 50,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Welcome to AIOS',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your private, on-device AI assistant.\n'
            'No internet required. Your data stays on your phone.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _FeatureItem(
            icon: Icons.psychology,
            title: 'Local AI',
            subtitle: 'Runs entirely on your device',
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.lock,
            title: 'Private',
            subtitle: 'No data leaves your phone',
          ),
          const SizedBox(height: 12),
          _FeatureItem(
            icon: Icons.smart_toy,
            title: 'Smart Agent',
            subtitle: 'Controls your phone with natural language',
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModelSetupPage extends StatelessWidget {
  const _ModelSetupPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.psychology,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          const Text(
            'Set Up Your AI Model',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'AIOS uses GGUF model files for on-device AI.\n'
            'You can import models later in Settings.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'How to get a model:',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _StepText('1. Download a GGUF model (e.g., Gemma 2B)'),
                _StepText('2. Place it in your Downloads folder'),
                _StepText('3. Go to Settings > Import Model'),
                _StepText('4. Select the downloaded .gguf file'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.security,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          const Text(
            'Permissions',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'AIOS needs certain permissions to control your phone. '
            'You can grant them later in Settings.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _PermissionItem(
            icon: Icons.folder,
            title: 'Storage',
            subtitle: 'Access model files',
          ),
          _PermissionItem(
            icon: Icons.accessibility_new,
            title: 'Accessibility',
            subtitle: 'Screen reading & control',
          ),
          _PermissionItem(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Read notifications',
          ),
          _PermissionItem(
            icon: Icons.contacts,
            title: 'Contacts',
            subtitle: 'Search contacts',
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
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

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 48,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'You\'re All Set!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Start by importing an AI model in Settings, '
            'then ask AIOS anything!',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
