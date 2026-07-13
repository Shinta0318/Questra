import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc_memory/arc_memory_management_preview_service.dart';
import 'package:questra/features/settings/widgets/arc_memory_management_preview_card.dart';

void main() {
  testWidgets('renders memory type previews and management actions', (
    tester,
  ) async {
    final preview = const ArcMemoryManagementPreviewService().buildPreview();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ArcMemoryManagementPreviewCard(preview: preview),
          ),
        ),
      ),
    );

    expect(find.text(preview.heading), findsOneWidget);
    expect(find.text('Quest Memory'), findsOneWidget);
    expect(find.text('Trail Memory'), findsOneWidget);
    expect(find.text('記憶を確認'), findsOneWidget);
    expect(find.text('エクスポート'), findsOneWidget);
  });
}
