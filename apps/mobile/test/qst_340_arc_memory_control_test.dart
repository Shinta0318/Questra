import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc_memory/arc_memory_control_screen.dart';
import 'package:questra/features/arc_memory/arc_memory_model.dart';
import 'package:questra/features/arc_memory/arc_memory_providers.dart';
import 'package:questra/features/arc_memory/arc_memory_repository.dart';
import 'package:questra/features/arc_memory/memory_extraction_service.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/trust/consent_controller.dart';
import 'package:questra/features/trust/consent_purpose_registry_service.dart';

void main() {
  test('denied personalization consent prevents Memory creation', () async {
    final repository = InMemoryArcMemoryRepository();
    final service = MemoryExtractionService(
      repository: repository,
      canRemember: (_) async => false,
    );

    final created = await service.extractAndSave(
      const MemoryExtractionEvent(
        userId: 'user-1',
        sourceType: ArcMemorySourceType.arcChat,
        text: 'このQuestを続ける理由をArcと一緒に見つけられた。',
      ),
    );

    expect(created, isEmpty);
    expect(await repository.findForControl('user-1'), isEmpty);
  });

  test(
    'do-not-remember request and sensitive content are not stored',
    () async {
      final repository = InMemoryArcMemoryRepository();
      final service = MemoryExtractionService(repository: repository);

      expect(requestsNoArcMemory('この会話は覚えないでください'), isTrue);
      expect(
        await service.extractAndSave(
          const MemoryExtractionEvent(
            userId: 'user-1',
            sourceType: ArcMemorySourceType.arcChat,
            text: 'この会話は覚えないでください。大切な相談です。',
          ),
        ),
        isEmpty,
      );
      expect(
        await service.extractAndSave(
          const MemoryExtractionEvent(
            userId: 'user-1',
            sourceType: ArcMemorySourceType.arcChat,
            text: '診断された病気についてArcと今後の生活を相談したい。',
          ),
        ),
        isEmpty,
      );
      expect(await repository.findForControl('user-1'), isEmpty);
    },
  );

  test('owner can correct and delete a stored Memory', () async {
    final repository = InMemoryArcMemoryRepository();
    final memory = ArcMemory(
      id: 'memory-1',
      userId: 'user-1',
      memoryType: ArcMemoryType.preferenceMemory,
      title: '以前の好み',
      content: '朝に進めたい',
      importanceScore: 0.7,
      emotionalTone: EmotionalTone.neutral,
      sourceType: ArcMemorySourceType.arcChat,
      provenance: const {'origin': 'arc_chat'},
      retentionUntil: DateTime.utc(2027),
    );
    await repository.save(memory);

    await repository.update(memory.copyWith(title: '今の好み', content: '夜に進めたい'));
    final updated = await repository.findForControl('user-1');
    expect(updated.single.title, '今の好み');
    expect(updated.single.provenance, containsPair('origin', 'arc_chat'));

    await repository.deleteById('user-1', 'memory-1');
    expect(await repository.findForControl('user-1'), isEmpty);
  });

  test('migration and tool layer enforce purpose consent', () {
    final root =
        Directory.current.path.endsWith('${Platform.pathSeparator}mobile')
        ? Directory.current.parent.parent
        : Directory.current;
    final migration = File(
      '${root.path}/supabase/migrations/'
      '202608180002_arc_memory_consent_control.sql',
    ).readAsStringSync();
    final toolServer = File(
      '${root.path}/supabase/functions/_shared/quest_planning/tool_server.ts',
    ).readAsStringSync();

    expect(migration, contains('arc_memory_consent_required'));
    expect(migration, contains('sensitive_arc_memory_prohibited'));
    expect(migration, contains('arc_memory_consent_events'));
    expect(migration, contains('get_relevant_arc_memories'));
    expect(toolServer, contains('hasArcMemoryConsent(context.userId)'));
    expect(toolServer, contains('rpc("get_relevant_arc_memories"'));
  });

  testWidgets('Control Center shows provenance and management actions', (
    tester,
  ) async {
    final repository = InMemoryArcMemoryRepository();
    await repository.save(
      ArcMemory(
        userId: 'user-1',
        memoryType: ArcMemoryType.questMemory,
        title: 'シンガポールへのQuest',
        content: '家族で文化と食事を楽しみたい。',
        importanceScore: 0.8,
        emotionalTone: EmotionalTone.positive,
        sourceType: ArcMemorySourceType.questCreated,
        provenance: const {'origin': 'quest_created'},
        retentionUntil: DateTime.utc(2027),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_AuthenticatedController.new),
          consentControllerProvider.overrideWith(_GrantedConsentController.new),
          arcMemoryRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ArcMemoryControlScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arcが覚えていること'), findsOneWidget);
    expect(find.text('シンガポールへのQuest'), findsOneWidget);
    expect(find.text('由来: Quest作成'), findsOneWidget);
    expect(find.byTooltip('記憶を訂正'), findsOneWidget);
    expect(find.byTooltip('記憶を削除'), findsOneWidget);
    expect(find.text('すべての記憶を削除'), findsOneWidget);
  });
}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'user-1',
      email: 'memory@example.invalid',
      nickname: 'Navigator',
      onboardingCompleted: true,
      legalAcceptanceCurrent: true,
    ),
  );
}

class _GrantedConsentController extends ConsentController {
  @override
  Future<Map<ConsentPurpose, ConsentDecision>> build() async => {
    ConsentPurpose.arcPersonalization: const ConsentDecision(
      status: ConsentStatus.granted,
      version: 1,
      source: 'settings',
    ),
  };
}
