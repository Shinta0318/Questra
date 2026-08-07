import 'package:flutter/material.dart';

class QuestraActionButton extends StatelessWidget {
  const QuestraActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.fullWidth = false,
    super.key,
  });

  final Widget icon;
  final Widget label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: label,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: color == null ? null : BorderSide(color: color),
        minimumSize: const Size(44, 44),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class QuestraMenuItem<T> {
  const QuestraMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
  final bool enabled;
}

class QuestraPopupMenu<T> extends StatelessWidget {
  const QuestraPopupMenu({
    required this.items,
    required this.onSelected,
    required this.tooltip,
    this.onOpened,
    super.key,
  });

  final List<QuestraMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      onOpened: onOpened,
      onSelected: onSelected,
      icon: const Icon(Icons.more_horiz),
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<T>(
            value: item.value,
            enabled: item.enabled,
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: item.destructive
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: item.destructive
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
