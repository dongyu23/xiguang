import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/typography.dart';

class XiguangChip extends StatelessWidget {
  const XiguangChip({
    super.key,
    required this.label,
    required this.selected,
    this.onSelected,
    this.leading,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return FilterChip(
      avatar: leading,
      label: Text(label, style: AppText.chip),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: theme.accent.withValues(alpha: .22),
      backgroundColor: theme.surface,
      side: BorderSide(color: selected ? theme.accent : theme.border),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill)),
    );
  }
}
