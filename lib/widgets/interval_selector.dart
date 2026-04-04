import 'package:flutter/material.dart';

class IntervalSelector extends StatelessWidget {
  final String currentInterval;
  final ValueChanged<String> onIntervalChanged;

  static const Map<String, String> _intervals = {
    '分时': '1m',
    '1m': '1m',
    '15m': '15m',
    '1H': '1h',
    '4H': '4h',
    '日K': '1d',
    '周K': '1w',
  };

  const IntervalSelector({
    super.key,
    required this.currentInterval,
    required this.onIntervalChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _intervals.entries.map((entry) {
            final label = entry.key;
            final value = entry.value;
            final isSelected = currentInterval == value;

            return _buildIntervalButton(
              label: label,
              isSelected: isSelected,
              colorScheme: colorScheme,
              onTap: () => onIntervalChanged(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIntervalButton({
    required String label,
    required bool isSelected,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
