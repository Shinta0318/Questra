import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/questra_surface_palette.dart';
import '../../l10n/app_localizations.dart';

Future<T?> showQuestraModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final previousFocus = FocusManager.instance.primaryFocus;
  try {
    return await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      enableDrag: false,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  } finally {
    if (context.mounted && previousFocus?.context != null) {
      previousFocus!.requestFocus();
    }
  }
}

/// Owns scrolling/insets and guards every non-submit dismissal of a draft.
class QuestraModalSheet extends StatefulWidget {
  const QuestraModalSheet({
    required this.title,
    required this.child,
    required this.hasUnsavedChanges,
    this.isBusy = false,
    this.dark = false,
    super.key,
  });

  final String title;
  final Widget child;
  final bool Function() hasUnsavedChanges;
  final bool isBusy;
  final bool dark;

  static void finish<T>(BuildContext context, [T? result]) {
    final state = context.findAncestorStateOfType<_QuestraModalSheetState>();
    if (state == null) {
      Navigator.of(context).pop(result);
      return;
    }
    state._finish(result);
  }

  @override
  State<QuestraModalSheet> createState() => _QuestraModalSheetState();
}

class _QuestraModalSheetState extends State<QuestraModalSheet> {
  bool _asking = false;
  bool _allowClose = false;

  void _finish<T>(T? result) {
    if (_allowClose || !mounted) return;
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _close() async {
    if (_asking || widget.isBusy) return;
    _asking = true;
    try {
      if (widget.hasUnsavedChanges()) {
        final copy = AppLocalizations.of(context)!;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(copy.discardChangesTitle),
            content: Text(copy.discardChangesBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(copy.continueEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(copy.discardAndClose),
              ),
            ],
          ),
        );
        if (discard != true) return;
      }
      if (mounted && !widget.isBusy) _finish(null);
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.dark
        ? QuestraSurfacePalette.dark
        : QuestraSurfacePalette.light;
    return PopScope(
      canPop: _allowClose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 840,
              maxHeight: MediaQuery.sizeOf(context).height * .92,
            ),
            child: Material(
              key: const Key('questra-modal-surface'),
              color: palette.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.title,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: palette.foreground),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: widget.isBusy ? null : _close,
                          color: palette.foreground,
                          disabledColor: palette.muted,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (widget.isBusy)
                      const LinearProgressIndicator(
                        color: AppColors.cosmicBlue,
                      ),
                    const SizedBox(height: 12),
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
