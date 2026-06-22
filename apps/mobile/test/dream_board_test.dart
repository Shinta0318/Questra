import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/dream_board/dream_board_controller.dart';
import 'package:questra/features/dream_board/dream_board_model.dart';
import 'package:questra/features/dream_board/dream_board_repository.dart';

void main() {
  test('Dream Board item types expose labels and storage keys', () {
    expect(DreamBoardItemType.vision.label, '理想イメージ');
    expect(DreamBoardItemType.reference.storageKey, 'reference');
    expect(
      dreamBoardItemTypeFromStorage('generated_background'),
      DreamBoardItemType.generatedBackground,
    );
  });

  test('in-memory repository returns Quest items newest first', () async {
    final repository = InMemoryDreamBoardRepository();
    final older = DreamBoardItem(
      questId: 'quest-1',
      title: 'Older',
      note: 'First spark',
      itemType: DreamBoardItemType.vision,
      createdAt: DateTime(2026, 6, 20),
    );
    final newer = DreamBoardItem(
      questId: 'quest-1',
      title: 'Newer',
      note: 'Latest spark',
      itemType: DreamBoardItemType.reference,
      createdAt: DateTime(2026, 6, 21),
    );

    await repository.save(ownerId: 'user-1', item: older);
    await repository.save(ownerId: 'user-1', item: newer);

    final items = await repository.findByQuestId('quest-1');

    expect(items.map((item) => item.title), ['Newer', 'Older']);
  });

  test('controller can add and remove a local Dream Board item', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(dreamBoardControllerProvider.notifier);
    await controller.addItem(
      questId: 'quest-1',
      title: '理想の到達点',
      note: 'Launch day image',
      itemType: DreamBoardItemType.vision,
    );

    final item = container.read(dreamBoardControllerProvider)['quest-1']!.first;
    expect(item.title, '理想の到達点');

    await controller.removeItem(item);

    expect(container.read(dreamBoardControllerProvider)['quest-1'], isEmpty);
  });
}
