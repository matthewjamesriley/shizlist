import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/app_router.dart';
import '../../../services/invite_service.dart';
import '../../../widgets/app_notification.dart';

/// Screen for accepting an invite via deep link
class AcceptInviteScreen extends StatefulWidget {
  final String inviteCode;

  const AcceptInviteScreen({super.key, required this.inviteCode});

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  final InviteService _inviteService = InviteService();
  bool _isProcessing = true;
  String? _errorMessage;
  String? _successMessage;
  String? _ownerName;
  String? _listTitle;

  @override
  void initState() {
    super.initState();
    _processInvite();
  }

  Future<void> _processInvite() async {
    try {
      final result = await _inviteService.acceptInvite(widget.inviteCode);

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _isProcessing = false;
            _successMessage = result['message'] as String?;
            _ownerName = result['ownerName'] as String?;
            _listTitle = result['listTitle'] as String?;
          });

          // Show success and navigate after a brief delay
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            context.go(AppRoutes.contacts);
            AppNotification.success(
              context,
              _successMessage ?? 'Invite accepted!',
            );
          }
        } else {
          setState(() {
            _isProcessing = false;
            _errorMessage = result['message'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error processing invite: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to process invite: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo or icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isProcessing
                        ? Icons.hourglass_empty
                        : _errorMessage != null
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 50,
                    color:
                        _errorMessage != null
                            ? AppColors.error
                            : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Status text
                Text(
                  _isProcessing
                      ? 'Processing invite...'
                      : _errorMessage ?? _successMessage ?? 'Success!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        _errorMessage != null
                            ? AppColors.error
                            : AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (_ownerName != null && _errorMessage == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _listTitle != null ? 'List: $_listTitle' : '',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 32),

                if (_isProcessing)
                  const CircularProgressIndicator(color: AppColors.primary)
                else if (_errorMessage != null) ...[
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.lists),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text('Go Home'),
                  ),
                ] else
                  // Auto-navigating, show subtle loading
                  Text(
                    'Taking you to My Friends...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
