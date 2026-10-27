import 'package:flutter/material.dart';

import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/widgets/anch_icon.dart';

class BackupPasswordTextFormField extends StatelessWidget {
  const BackupPasswordTextFormField({
    super.key,
    required this.controller,
    required this.obscureText,
    required this.hintText,
    required this.onChanged,
    required this.onToggleVisibility,
    required this.validator,
    this.focusNode,
    this.enabled = true,
    this.helperText,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool obscureText;
  final String hintText;
  final String? helperText;
  final ValueChanged<String> onChanged;
  final VoidCallback onToggleVisibility;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      obscureText: obscureText,
      style: TextStyle(color: context.anchColors.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        helperText: helperText,
        helperMaxLines: 3,
        helperStyle: TextStyle(
          color: context.anchColors.textMuted,
          fontSize: 12,
        ),
        hintStyle: TextStyle(color: context.anchColors.textMuted, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: context.anchColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: context.anchColors.borderStrong),
        ),
        filled: true,
        fillColor: context.anchColors.surface,
        suffixIcon: Semantics(
          button: true,
          label: obscureText ? '显示密码' : '隐藏密码',
          child: InkWell(
            onTap: enabled ? onToggleVisibility : null,
            splashFactory: NoSplash.splashFactory,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnchIcon(
                  obscureText ? AnchIcons.visibilityOff : AnchIcons.visibility,
                  color: context.anchColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
      validator: validator,
    );
  }
}
