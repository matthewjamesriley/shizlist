import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/shizlist_logo.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/otp_input.dart';

/// Login screen for returning users
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpInputKey = GlobalKey<OtpInputState>();
  final _authService = AuthService();
  String _otpCode = '';

  bool _isLoading = false;
  String? _errorMessage;
  bool _showEmailLogin = false;
  bool _showOtpVerification = false;
  String? _pendingEmail;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithOtp(email: _emailController.text.trim());

      if (mounted) {
        setState(() {
          _pendingEmail = _emailController.text.trim();
          _showOtpVerification = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send verification email. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_pendingEmail == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithOtp(email: _pendingEmail!);

      if (mounted) {
        setState(() => _isLoading = false);
        AppNotification.success(context, 'Code resent! Check your email.');
        _otpInputKey.currentState?.clear();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend code. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyOtp([String? code]) async {
    final otpCode = code ?? _otpCode;
    if (otpCode.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.verifyOtp(email: _pendingEmail!, token: otpCode);

      if (mounted) {
        context.go(AppRoutes.lists);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid or expired code. Please try again.';
        _isLoading = false;
      });
      _otpInputKey.currentState?.clear();
    }
  }

  // TODO: Re-enable social login later
  // Future<void> _handleSocialLogin(SocialProvider provider) async {
  //   setState(() {
  //     _isLoading = true;
  //     _errorMessage = null;
  //   });
  //
  //   try {
  //     await _authService.signInWithProvider(provider);
  //   } catch (e) {
  //     setState(() {
  //       _errorMessage = 'Failed to sign in. Please try again.';
  //     });
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //     }
  //   }
  // }

  void _goBack() {
    if (_showOtpVerification) {
      setState(() {
        _showOtpVerification = false;
        _otpCode = '';
      });
      _otpInputKey.currentState?.clear();
    } else if (_showEmailLogin) {
      setState(() => _showEmailLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button at top when showing forms
              if (_showEmailLogin || _showOtpVerification) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: _goBack,
                    child: PhosphorIcon(
                      PhosphorIcons.arrowLeft(),
                      size: 28,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                const SizedBox(height: 40),
              ],

              // Logo - hide when showing forms
              if (!_showEmailLogin && !_showOtpVerification) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: const ShizListLogo(height: 50),
                  ),
                ),
                const SizedBox(height: 48),
              ],

              // Title
              Text(
                _showOtpVerification ? 'Check your email' : 'Welcome back',
                style: GoogleFonts.lato(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              // Subtitle
              if (!_showEmailLogin && !_showOtpVerification) ...[
                const SizedBox(height: 12),
                Text(
                  'Log in to continue.',
                  style: GoogleFonts.lato(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (_showOtpVerification) ...[
                const SizedBox(height: 12),
                Text(
                  'We sent a verification code to\n$_pendingEmail',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 40),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.warningCircle(),
                        color: AppColors.error,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.lato(
                            fontSize: 16,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // OTP Verification form
              if (_showOtpVerification) ...[
                OtpInput(
                  key: _otpInputKey,
                  autofocus: true,
                  onChanged: (code) => setState(() => _otpCode = code),
                  onCompleted: (code) {
                    setState(() => _otpCode = code);
                    _handleVerifyOtp(code);
                  },
                ),

                const SizedBox(height: 24),

                AppButton.primary(
                  label: 'Verify',
                  onPressed: _isLoading ? null : () => _handleVerifyOtp(),
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 16),

                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _handleResendOtp,
                    child: Text(
                      'Resend code',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ]
              // Main login buttons
              else if (!_showEmailLogin) ...[
                // Log in with email
                _SocialButton(
                  label: 'Log in with email',
                  icon: PhosphorIcons.envelope(),
                  onPressed:
                      _isLoading
                          ? null
                          : () => setState(() => _showEmailLogin = true),
                  backgroundColor: AppColors.primary,
                  textColor: Colors.white,
                ),

                // TODO: Re-enable social login later
                // const SizedBox(height: 16),
                //
                // // Log in with Google
                // _SocialButton(
                //   label: 'Log in with Google',
                //   icon: PhosphorIcons.googleLogo(),
                //   onPressed:
                //       _isLoading
                //           ? null
                //           : () => _handleSocialLogin(SocialProvider.google),
                //   backgroundColor: AppColors.accent,
                //   textColor: Colors.white,
                // ),
                //
                // const SizedBox(height: 16),
                //
                // // Log in with Apple
                // _SocialButton(
                //   label: 'Log in with Apple',
                //   icon: PhosphorIcons.appleLogo(),
                //   onPressed:
                //       _isLoading
                //           ? null
                //           : () => _handleSocialLogin(SocialProvider.apple),
                //   backgroundColor: Colors.black,
                //   textColor: Colors.white,
                // ),
                const SizedBox(height: 32),

                // Don't have an account
                Text(
                  "Don't have an account?",
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Sign up button
                _SocialButton(
                  label: 'Sign up',
                  icon: PhosphorIcons.userPlus(),
                  onPressed: () => context.go(AppRoutes.signup),
                  backgroundColor: Colors.white,
                  textColor: AppColors.primary,
                  borderColor: AppColors.primary,
                ),
              ]
              // Email login form (just email)
              else ...[
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _emailController,
                        hint: 'Email',
                        icon: PhosphorIcons.envelope(),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      Text(
                        "You'll receiverr a verification code to log in.",
                        style: GoogleFonts.lato(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      AppButton.primary(
                        label: 'Continue',
                        onPressed: _isLoading ? null : _handleSendOtp,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Signup link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.signup),
                      child: Text(
                        'Sign up',
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextAlign textAlign = TextAlign.start,
    bool autofocus = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textAlign: textAlign,
      autofocus: autofocus,
      style: GoogleFonts.lato(fontSize: 18, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.lato(fontSize: 18, color: AppColors.textHint),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: PhosphorIcon(icon, color: AppColors.textPrimary, size: 24),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: validator,
    );
  }
}

/// Social login button with custom colors (for Google, Apple, Facebook branding)
class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side:
                borderColor != null
                    ? BorderSide(color: borderColor!, width: 1.5)
                    : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(icon, size: 22, color: textColor),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.lato(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
