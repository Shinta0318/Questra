import 'package:flutter/material.dart';

Future<DateTime?> showYearMonthPicker({
  required BuildContext context,
  DateTime? initialValue,
}) {
  final now = DateTime.now();
  var year = initialValue?.year ?? now.year;
  var month = initialValue?.month ?? now.month;
  return showDialog<DateTime>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('叶えたい月'),
        content: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: '年'),
                items: [
                  for (var value = now.year; value <= now.year + 10; value++)
                    DropdownMenuItem(value: value, child: Text('$value年')),
                ],
                onChanged: (value) => setState(() => year = value ?? year),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(labelText: '月'),
                items: [
                  for (var value = 1; value <= 12; value++)
                    DropdownMenuItem(value: value, child: Text('$value月')),
                ],
                onChanged: (value) => setState(() => month = value ?? month),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final selected = DateTime(year, month);
              if (selected.isBefore(DateTime(now.year, now.month))) return;
              Navigator.pop(context, selected);
            },
            child: const Text('この月にする'),
          ),
        ],
      ),
    ),
  );
}
