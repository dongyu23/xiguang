import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';

/// 月份选择结果
class MonthPickerResult {
  const MonthPickerResult(this.month);

  final DateTime? month;
}

/// 月份选择底部弹窗
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    super.key,
    required this.months,
    required this.selectedMonth,
    required this.nightMode,
  });

  final List<DateTime> months;
  final DateTime? selectedMonth;
  final bool nightMode;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final initial = widget.selectedMonth ?? DateTime(now.year, now.month);
    _year = initial.year;
    _month = initial.month;
  }

  List<int> get _years {
    final years = widget.months.map((month) => month.year).toList();
    years.add(DateTime.now().year);
    years.add(_year);
    final minYear = years.reduce((a, b) => a < b ? a : b) - 2;
    final maxYear = years.reduce((a, b) => a > b ? a : b) + 2;
    return [for (var year = maxYear; year >= minYear; year--) year];
  }

  List<int> get _monthsForYear {
    return const [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1];
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.nightMode ? AppText.nightInk : AppColors.ink;
    final muted = widget.nightMode ? AppText.nightInkMuted : AppColors.inkMuted;
    final sheetColor = widget.nightMode ? AppColors.nightWave : AppColors.white;
    final lineColor = widget.nightMode
        ? AppColors.white.withValues(alpha: 0.12)
        : AppColors.line;
    final selected = DateTime(_year, _month);

    final maxHeight = MediaQuery.sizeOf(context).height * .72;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final pickerHeight =
                (constraints.maxHeight - 154).clamp(76.0, 128.0);
            return Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s22, AppSpacing.sm,
                  AppSpacing.s22, AppSpacing.s10),
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: lineColor,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(
                      child: Text(
                        '按日期筛选',
                        style: AppText.onNight(
                            AppText.titleMedium, widget.nightMode),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(72, 32),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context)
                          .pop(const MonthPickerResult(null)),
                      child: Text(
                        '全部日期',
                        style: AppText.chip.copyWith(color: AppColors.teaGreen),
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.s6),
                  Divider(color: lineColor, height: 1),
                  SizedBox(
                    height: pickerHeight,
                    child: Row(children: [
                      Expanded(
                        child: _PickerColumn(
                          values: _years,
                          selectedValue: _year,
                          suffix: '年',
                          foreground: foreground,
                          muted: muted,
                          nightMode: widget.nightMode,
                          onSelected: (value) => setState(() => _year = value),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: (pickerHeight - 28).clamp(44.0, 82.0),
                          color: lineColor),
                      Expanded(
                        child: _PickerColumn(
                          values: _monthsForYear,
                          selectedValue: _month,
                          suffix: '月',
                          foreground: foreground,
                          muted: muted,
                          nightMode: widget.nightMode,
                          onSelected: (value) => setState(() => _month = value),
                        ),
                      ),
                    ]),
                  ),
                  Divider(color: lineColor, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: BorderSide(color: lineColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(
                          '取消',
                          style: AppText.chip.copyWith(color: muted),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pop(MonthPickerResult(selected)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.teaGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: const Text('确定'),
                      ),
                    ),
                  ]),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PickerColumn extends StatelessWidget {
  const _PickerColumn({
    required this.values,
    required this.selectedValue,
    required this.suffix,
    required this.foreground,
    required this.muted,
    required this.nightMode,
    required this.onSelected,
  });

  final List<int> values;
  final int selectedValue;
  final String suffix;
  final Color foreground;
  final Color muted;
  final bool nightMode;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s6, horizontal: AppSpacing.s10),
      itemCount: values.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final value = values[index];
        final selected = value == selectedValue;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => onSelected(value),
            child: Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.teaGreen
                        .withValues(alpha: nightMode ? 0.18 : 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                '$value$suffix',
                style: AppText.titleSmall.copyWith(
                  color: selected ? foreground : muted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
