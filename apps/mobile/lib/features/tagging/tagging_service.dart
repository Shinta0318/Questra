import '../arc_memory/arc_memory_model.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';
import 'ai_tag_service.dart';
import 'tag_model.dart';
import 'tag_repository.dart';

class TaggingService {
  const TaggingService({required this.aiTagService, required this.repository});

  final AiTagService aiTagService;
  final TagRepository repository;

  Future<EntityTagsResult> tagQuest({
    required String ownerId,
    required Quest quest,
  }) {
    return _tag(
      TaggingInput(
        ownerId: ownerId,
        entityType: TagEntityType.quest,
        entityId: quest.id,
        title: quest.title,
        body: quest.description,
        context: {
          'category': quest.category,
          'difficulty': quest.difficulty.storageKey,
          'status': quest.status.storageKey,
        },
      ),
    );
  }

  Future<EntityTagsResult> tagMission({
    required String ownerId,
    required Mission mission,
  }) {
    return _tag(
      TaggingInput(
        ownerId: ownerId,
        entityType: TagEntityType.mission,
        entityId: mission.id,
        title: mission.title,
        body: '${mission.description}\n${mission.questTitle}',
        context: {
          'quest_id': mission.questId,
          'guide_type': mission.guideType.storageKey,
          'difficulty': mission.difficulty.storageKey,
          'status': mission.status.storageKey,
        },
      ),
    );
  }

  Future<EntityTagsResult> tagTrail({
    required String ownerId,
    required Trail trail,
  }) {
    return _tag(
      TaggingInput(
        ownerId: ownerId,
        entityType: TagEntityType.trail,
        entityId: trail.id,
        title: trail.title,
        body: '${trail.summary}\n${trail.content}',
        context: {
          'quest_id': trail.questId,
          'mission_id': trail.missionId,
          'trail_type': trail.trailType.storageKey,
          'source_type': trail.sourceType,
        },
      ),
    );
  }

  Future<EntityTagsResult> tagArcMemory(ArcMemory memory) {
    return _tag(
      TaggingInput(
        ownerId: memory.userId,
        entityType: TagEntityType.arcMemory,
        entityId: memory.id,
        title: memory.title,
        body: memory.content,
        context: {
          'quest_id': memory.questId,
          'mission_id': memory.missionId,
          'trail_id': memory.trailId,
          'memory_type': memory.memoryType.storageKey,
          'source_type': memory.sourceType.storageKey,
          'importance_score': memory.importanceScore,
        },
      ),
    );
  }

  Future<List<EntityTagsResult>> searchByTag({
    required String ownerId,
    required String query,
    int limit = 30,
  }) {
    return repository.searchByTag(ownerId: ownerId, query: query, limit: limit);
  }

  Future<List<TagStat>> stats({required String ownerId, int limit = 20}) {
    return repository.stats(ownerId: ownerId, limit: limit);
  }

  Future<EntityTagsResult> _tag(TaggingInput input) async {
    final generatedTags = await aiTagService.generateTags(input);
    return repository.saveEntityTags(input: input, tags: generatedTags);
  }
}
