import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/widgets/forms/arc_chat_keyboard_contract.dart';

void main() {
  const maxLength = 1200;
  KeyDownEvent enterDown() => const KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      );
  KeyRepeatEvent enterRepeat() => const KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.enter,
        logicalKey: LogicalKeyboardKey.enter,
        timeStamp: Duration.zero,
      );

  ArcChatKeyAction resolve({
    required KeyEvent event,
    bool alt = false,
    bool composing = false,
    bool sending = false,
    String text = 'こんにちは',
  }) =>
      ArcChatKeyboardContract.resolve(
        event: event,
        isAltPressed: alt,
        isComposing: composing,
        isSending: sending,
        text: text,
        maxLength: maxLength,
      );

  test('Enter sends a non-empty message', () {
    expect(
      resolve(event: enterDown()),
      ArcChatKeyAction.send,
    );
  });

  test('Alt Enter inserts a newline', () {
    expect(
      resolve(
        event: enterDown(),
        alt: true,
      ),
      ArcChatKeyAction.insertNewline,
    );
  });

  test('Enter during Japanese IME composition never sends', () {
    expect(
      resolve(
        event: enterDown(),
        composing: true,
      ),
      ArcChatKeyAction.ignore,
    );
  });

  test('empty, repeated, and in-flight submissions are ignored', () {
    final down = enterDown();
    expect(resolve(event: down, text: '   '), ArcChatKeyAction.ignore);
    expect(resolve(event: down, sending: true), ArcChatKeyAction.ignore);
    expect(
      resolve(
        event: enterRepeat(),
      ),
      ArcChatKeyAction.ignore,
    );
  });
}
