import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/layout/questra_responsive_layout.dart';
import 'package:questra/core/layout/questra_scroll_behavior.dart';
import 'package:questra/widgets/layout/questra_responsive_list_view.dart';

void main() {
  test('classifies compact, medium, and expanded widths', () {
    expect(
      QuestraLayoutSpec.fromWidth(599).windowClass,
      QuestraWindowClass.compact,
    );
    expect(
      QuestraLayoutSpec.fromWidth(600).windowClass,
      QuestraWindowClass.medium,
    );
    expect(
      QuestraLayoutSpec.fromWidth(1023).windowClass,
      QuestraWindowClass.medium,
    );
    expect(
      QuestraLayoutSpec.fromWidth(1024).windowClass,
      QuestraWindowClass.expanded,
    );
  });

  testWidgets('caps expanded list content and keeps it centered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestraResponsiveListView(
            children: [Text('Responsive content')],
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ListView)).width, 960);
    expect(tester.getTopLeft(find.byType(ListView)).dx, 120);
  });

  testWidgets('refresh callback is exposed by the responsive list', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const QuestraScrollBehavior(),
        home: Scaffold(
          body: QuestraResponsiveListView(
            onRefresh: () async => refreshCount++,
            children: const [Text('Refreshable content')],
          ),
        ),
      ),
    );

    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();

    expect(refreshCount, 1);
    expect(
      const QuestraScrollBehavior().dragDevices,
      contains(PointerDeviceKind.mouse),
    );
  });
}
