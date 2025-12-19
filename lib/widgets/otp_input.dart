import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';

/// A visually appealing OTP input with 6 separate digit boxes
class OtpInput extends StatefulWidget {
  final Function(String) onCompleted;
  final Function(String)? onChanged;
  final bool autofocus;

  const OtpInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.autofocus = true,
  });

  @override
  State<OtpInput> createState() => OtpInputState();
}

class OtpInputState extends State<OtpInput> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get otp => _controllers.map((c) => c.text).join();

  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    setState(() {});
    _focusNodes[0].requestFocus();
  }

  void _handlePaste(String pastedText, int startIndex) {
    final digits = pastedText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;

    // Clear the current field first since it might have extra characters
    _controllers[startIndex].clear();

    // Distribute digits across all boxes starting from index 0 for full paste
    final effectiveStart = digits.length >= 6 ? 0 : startIndex;

    for (int i = 0; i < digits.length && i + effectiveStart < 6; i++) {
      _controllers[i + effectiveStart].text = digits[i];
    }

    setState(() {});

    final filledCount = effectiveStart + digits.length;
    if (filledCount >= 6) {
      FocusScope.of(context).unfocus();
      _checkCompleted();
    } else {
      _focusNodes[filledCount.clamp(0, 5)].requestFocus();
    }

    widget.onChanged?.call(otp);
  }

  void _onChanged(int index, String value) {
    // Handle paste - if more than 1 character, distribute across boxes
    if (value.length > 1) {
      _handlePaste(value, index);
      return;
    }

    // Ensure only single digit remains
    if (value.length == 1) {
      _controllers[index].text = value;
    }

    setState(() {});

    // Move to next field if digit entered
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Check if all fields are filled
    _checkCompleted();

    // Notify change
    widget.onChanged?.call(otp);
  }

  void _checkCompleted() {
    final code = otp;
    if (code.length == 6) {
      widget.onCompleted(code);
    }
  }

  void _handleKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_controllers[index].text.isEmpty && index > 0) {
          _controllers[index - 1].clear();
          setState(() {});
          _focusNodes[index - 1].requestFocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate box size based on screen width to prevent overflow
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = 64.0; // 32px on each side
    final totalGaps = 38.0; // 5 gaps of 6px + 1 extra gap of 8px
    final availableWidth = screenWidth - horizontalPadding - totalGaps;
    final boxSize = (availableWidth / 6).clamp(42.0, 50.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (index) {
        final isFilled = _controllers[index].text.isNotEmpty;

        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : 6,
            right: index == 2 ? 8 : 0, // Extra gap after 3rd digit
          ),
          child: SizedBox(
            width: boxSize,
            height: boxSize + 6,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) => _handleKeyEvent(index, event),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6, // Allow paste of full code
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: boxSize * 0.5,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor:
                      isFilled
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isFilled ? AppColors.primary : AppColors.divider,
                      width: 1,
                    ),
                  ),
                ),
                onChanged: (value) => _onChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}
