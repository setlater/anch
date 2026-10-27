import 'package:flutter/cupertino.dart';
import '../../core/widgets/anch_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';

class ItemEntryTextField extends StatelessWidget {
  const ItemEntryTextField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.scrollPadding,
    required this.keyboardType,
    required this.inputFormatters,
    required this.maxLines,
    required this.minLines,
    required this.fillColor,
    required this.onChanged,
    this.helperText,
    this.hintText,
    this.maxLength,
  });

  final String fieldKey;
  final String label;
  final TextEditingController? controller;
  final FocusNode focusNode;
  final EdgeInsets scrollPadding;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final int maxLines;
  final int minLines;
  final Color fillColor;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final String? hintText;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: Key('item_field_control_$fieldKey'),
            controller: controller,
            style: TextStyle(
              fontSize: 16,
              color: context.anchColors.textPrimary,
            ),
            focusNode: focusNode,
            scrollPadding: scrollPadding,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            minLines: minLines,
            maxLength: maxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter: maxLength == null
                ? null
                : (
                    context, {
                    required currentLength,
                    required maxLength,
                    required isFocused,
                  }) => null,
            enableInteractiveSelection: true,
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: editableTextState.contextMenuButtonItems,
              );
            },
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AnchRadius.sm),
                borderSide: BorderSide(color: context.anchColors.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AnchRadius.sm),
                borderSide: BorderSide(color: context.anchColors.borderStrong),
              ),
              filled: true,
              fillColor: fillColor,
            ),
            onChanged: onChanged,
          ),
          if (helperText != null) ...[
            const SizedBox(height: AnchSpacing.xs),
            Text(
              helperText!,
              key: Key('item_field_helper_$fieldKey'),
              softWrap: true,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: context.anchColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ItemEntryGenderSelector extends StatelessWidget {
  final String fieldLabel;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool hasError;

  const ItemEntryGenderSelector({
    super.key,
    required this.fieldLabel,
    required this.value,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMale = value == '男';
    final isFemale = value == '女';

    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            selected: isMale,
            label: '$fieldLabel－男',
            child: GestureDetector(
              onTap: () => onChanged('男'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isMale
                      ? context.anchColors.accentSoft
                      : context.anchColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMale
                        ? context.anchColors.accent
                        : context.anchColors.divider,
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: Text(
                    '男',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isMale ? FontWeight.bold : FontWeight.normal,
                      color: isMale
                          ? context.anchColors.accent
                          : context.anchColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AnchSpacing.md),
        Expanded(
          child: Semantics(
            button: true,
            selected: isFemale,
            label: '$fieldLabel－女',
            child: GestureDetector(
              onTap: () => onChanged('女'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isFemale
                      ? context.anchColors.accentSoft
                      : context.anchColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFemale
                        ? context.anchColors.accent
                        : context.anchColors.divider,
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: Text(
                    '女',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFemale
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isFemale
                          ? context.anchColors.accent
                          : context.anchColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ItemEntryTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;

  const ItemEntryTimePicker({super.key, required this.initialTime});

  @override
  State<ItemEntryTimePicker> createState() => _ItemEntryTimePickerState();
}

class _ItemEntryTimePickerState extends State<ItemEntryTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnchBottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnchBottomSheetPickerHeader(
            title: '选择出生时间',
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(
              context,
            ).pop(TimeOfDay(hour: _selectedHour, minute: _selectedMinute)),
          ),
          Divider(height: 1, thickness: 1, color: context.anchColors.divider),
          SizedBox(
            height: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour column
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _hourController,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedHour = index;
                      });
                    },
                    children: List.generate(24, (hour) {
                      return Center(
                        child: Text(
                          hour.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 20,
                            color: context.anchColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Center(
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: context.anchColors.textPrimary,
                    ),
                  ),
                ),
                // Minute column
                Expanded(
                  child: CupertinoPicker(
                    scrollController: _minuteController,
                    itemExtent: 40,
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMinute = index;
                      });
                    },
                    children: List.generate(60, (minute) {
                      return Center(
                        child: Text(
                          minute.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 20,
                            color: context.anchColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }),
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

class ItemEntryDatePicker extends StatefulWidget {
  const ItemEntryDatePicker({super.key, required this.initialDate});

  final DateTime initialDate;

  @override
  State<ItemEntryDatePicker> createState() => _ItemEntryDatePickerState();
}

class _ItemEntryDatePickerState extends State<ItemEntryDatePicker> {
  static const _firstYear = 1900;
  static const _lastYear = 2100;

  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _dayController;

  @override
  void initState() {
    super.initState();
    final initialYear = widget.initialDate.year
        .clamp(_firstYear, _lastYear)
        .toInt();
    _selectedYear = initialYear;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day
        .clamp(1, DateUtils.getDaysInMonth(_selectedYear, _selectedMonth))
        .toInt();
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _firstYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - 1,
    );
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _updateYear(int year) {
    setState(() {
      _selectedYear = year;
      _clampDay();
    });
  }

  void _updateMonth(int month) {
    setState(() {
      _selectedMonth = month;
      _clampDay();
    });
  }

  void _clampDay() {
    final maxDay = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    if (_selectedDay <= maxDay) return;
    _selectedDay = maxDay;
    _dayController.jumpToItem(maxDay - 1);
  }

  Widget _buildPicker({
    required Key key,
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onSelectedItemChanged,
    required String Function(int index) labelForIndex,
  }) {
    return Expanded(
      child: CupertinoPicker(
        key: key,
        scrollController: controller,
        itemExtent: 40,
        onSelectedItemChanged: onSelectedItemChanged,
        children: List.generate(
          itemCount,
          (index) => Center(
            child: Text(
              labelForIndex(index),
              style: TextStyle(
                fontSize: 20,
                color: context.anchColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    return AnchBottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnchBottomSheetPickerHeader(
            title: '选择日期',
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(
              context,
            ).pop(DateTime(_selectedYear, _selectedMonth, _selectedDay)),
          ),
          Divider(height: 1, thickness: 1, color: context.anchColors.divider),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                _buildPicker(
                  key: const Key('date_picker_year'),
                  controller: _yearController,
                  itemCount: _lastYear - _firstYear + 1,
                  onSelectedItemChanged: (index) =>
                      _updateYear(_firstYear + index),
                  labelForIndex: (index) => '${_firstYear + index} 年',
                ),
                _buildPicker(
                  key: const Key('date_picker_month'),
                  controller: _monthController,
                  itemCount: 12,
                  onSelectedItemChanged: (index) => _updateMonth(index + 1),
                  labelForIndex: (index) => '${index + 1} 月',
                ),
                _buildPicker(
                  key: const Key('date_picker_day'),
                  controller: _dayController,
                  itemCount: dayCount,
                  onSelectedItemChanged: (index) {
                    setState(() => _selectedDay = index + 1);
                  },
                  labelForIndex: (index) => '${index + 1} 日',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemEntryDayOfMonthPicker extends StatefulWidget {
  final int initialDay;

  const ItemEntryDayOfMonthPicker({super.key, required this.initialDay});

  @override
  State<ItemEntryDayOfMonthPicker> createState() =>
      _ItemEntryDayOfMonthPickerState();
}

class _ItemEntryDayOfMonthPickerState extends State<ItemEntryDayOfMonthPicker> {
  late int _selectedDay;
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay.clamp(1, 31);
    _controller = FixedExtentScrollController(initialItem: _selectedDay - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnchBottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnchBottomSheetPickerHeader(
            title: '选择日期',
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: () => Navigator.of(context).pop(_selectedDay),
          ),
          Divider(height: 1, thickness: 1, color: context.anchColors.divider),
          SizedBox(
            height: 220,
            child: CupertinoPicker(
              scrollController: _controller,
              itemExtent: 40,
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedDay = index + 1;
                });
              },
              children: List.generate(31, (index) {
                final day = index + 1;
                return Center(
                  child: Text(
                    '每月 $day 日',
                    style: TextStyle(
                      fontSize: 20,
                      color: context.anchColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
