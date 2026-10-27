import 'package:flutter/material.dart';

class ItemEntryFieldLabel extends StatelessWidget {
  const ItemEntryFieldLabel({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.required,
    required this.textColor,
    required this.requiredColor,
  });

  final String fieldKey;
  final String label;
  final bool required;
  final Color textColor;
  final Color requiredColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        key: Key('item_field_label_$fieldKey'),
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  color: requiredColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
