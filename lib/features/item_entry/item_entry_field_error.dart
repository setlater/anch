import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../../core/theme/anch_colors.dart';

class ItemEntryFieldError extends StatelessWidget {
  const ItemEntryFieldError({
    super.key,
    required this.message,
    required this.fieldKey,
  });

  final String? message;
  final String fieldKey;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              key: Key('item_field_error_$fieldKey'),
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnchIcon(
                    AnchIcons.warning,
                    size: 14,
                    color: context.anchColors.danger,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.anchColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
