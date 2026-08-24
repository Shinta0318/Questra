import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc_memory/arc_memory_management_preview_service.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';

void main() {
  const service = ArcMemoryManagementPreviewService();

  test('builds Arc Memory management preview without mutating data', () {
    final preview = service.buildPreview();

    expect(preview.heading, 'Arc Memory');
    expect(
      preview.typePreviews.map((type) => type.type),
      containsAll([
        ArcMemoryType.questMemory,
        ArcMemoryType.missionMemory,
        ArcMemoryType.trailMemory,
        ArcMemoryType.arcRelationshipMemory,
        ArcMemoryType.emotionalMemory,
      ]),
    );
    expect(
      preview.actions.map((action) => action.action),
      containsAll(ArcMemoryManagementAction.values),
    );
    expect(
      preview.actions
          .firstWhere(
            (action) => action.action == ArcMemoryManagementAction.delete,
          )
          .statusLabel,
      '利用可能',
    );
  });
}
