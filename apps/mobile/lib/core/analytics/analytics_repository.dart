import 'analytics_event.dart';

abstract class AnalyticsRepository {
  Future<void> record(AnalyticsEvent event);
}

class LocalSafeAnalyticsRepository implements AnalyticsRepository {
  final List<AnalyticsEvent> _events = [];

  List<AnalyticsEvent> get events => List.unmodifiable(_events);

  @override
  Future<void> record(AnalyticsEvent event) async {
    _events.add(
      AnalyticsEvent(
        name: event.name,
        userId: event.userId,
        properties: AnalyticsPayloadRules.sanitize(event.properties),
        createdAt: event.createdAt,
      ),
    );
  }
}

class NoopAnalyticsRepository implements AnalyticsRepository {
  const NoopAnalyticsRepository();

  @override
  Future<void> record(AnalyticsEvent event) async {}
}
