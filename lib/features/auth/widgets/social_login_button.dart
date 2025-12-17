import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/auth_service.dart';

/// Social login button widget
class SocialLoginButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback? onPressed;
  final bool isSignUp;

  const SocialLoginButton({
    super.key,
    required this.provider,
    this.onPressed,
    this.isSignUp = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        backgroundColor: _backgroundColor,
        foregroundColor: _textColor,
        side: BorderSide(color: _borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Text(
            isSignUp ? 'Sign up with $_providerName' : 'Continue with $_providerName',
            style: AppTypography.buttonText.copyWith(
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    switch (provider) {
      case SocialProvider.google:
        return Image.network(
          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          width: 24,
          height: 24,
          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
        );
      case SocialProvider.apple:
        return const Icon(Icons.apple, size: 24);
      case SocialProvider.facebook:
        return const Icon(Icons.facebook, size: 24, color: Color(0xFF1877F2));
    }
  }

  String get _providerName {
    switch (provider) {
      case SocialProvider.google:
        return 'Google';
      case SocialProvider.apple:
        return 'Apple';
      case SocialProvider.facebook:
        return 'Facebook';
    }
  }

  Color get _backgroundColor {
    switch (provider) {
      case SocialProvider.google:
        return Colors.white;
      case SocialProvider.apple:
        return Colors.black;
      case SocialProvider.facebook:
        return Colors.white;
    }
  }

  Color get _textColor {
    switch (provider) {
      case SocialProvider.google:
        return AppColors.textPrimary;
      case SocialProvider.apple:
        return Colors.white;
      case SocialProvider.facebook:
        return AppColors.textPrimary;
    }
  }

  Color get _borderColor {
    switch (provider) {
      case SocialProvider.google:
        return AppColors.border;
      case SocialProvider.apple:
        return Colors.black;
      case SocialProvider.facebook:
        return AppColors.border;
    }
  }
}


