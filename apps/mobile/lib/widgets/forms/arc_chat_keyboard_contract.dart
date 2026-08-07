import 'package:flutter/services.dart';

enum ArcChatKeyAction { ignore, send, insertNewline }

abstract final class ArcChatKeyboardContract {
  static ArcChatKeyAction resolve({
    required KeyEvent event,
    required bool isAltPressed,
    required bool isComposing,
    required bool isSending,
    required String text,
    required int maxLength,
  }) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
      return ArcChatKeyAction.ignore;
    }
    if (isComposing) return ArcChatKeyAction.ignore;
    if (isAltPressed) return ArcChatKeyAction.insertNewline;
    final trimmed = text.trim();
    if (isSending || trimmed.isEmpty || text.length > maxLength) {
      return ArcChatKeyAction.ignore;
    }
    return ArcChatKeyAction.send;
  }
}
