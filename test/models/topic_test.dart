import 'dart:convert';

import 'package:engram/src/models/topic.dart';
import 'package:test/test.dart';

void main() {
  group('Topic', () {
    test('fromJson/toJson round-trips', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Agent Skills',
        description: 'Anthropic agent skills course',
        documentIds: {'doc-1', 'doc-2', 'doc-3'},
        createdAt: '2026-02-18T00:00:00.000Z',
        lastIngestedAt: '2026-02-18T01:00:00.000Z',
      );

      final json = topic.toJson();
      final restored = Topic.fromJson(json);

      expect(restored.id, topic.id);
      expect(restored.name, topic.name);
      expect(restored.description, topic.description);
      expect(restored.documentIds, topic.documentIds);
      expect(restored.createdAt, topic.createdAt);
      expect(restored.lastIngestedAt, topic.lastIngestedAt);
    });

    test('fromJson handles missing optional fields', () {
      final topic = Topic.fromJson({
        'id': 'topic-1',
        'name': 'Test',
        'createdAt': '2026-02-18T00:00:00.000Z',
      });

      expect(topic.description, isNull);
      expect(topic.documentIds, isEmpty);
      expect(topic.lastIngestedAt, isNull);
    });

    test('toJson omits null optional fields', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Test',
        createdAt: '2026-02-18T00:00:00.000Z',
      );

      final json = topic.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('lastIngestedAt'), isFalse);
      expect(json['documentIds'], isEmpty);
    });

    test('equality is based on id', () {
      final t1 = Topic(
        id: 'topic-1',
        name: 'Name 1',
        createdAt: '2026-02-18T00:00:00.000Z',
      );
      final t2 = Topic(
        id: 'topic-1',
        name: 'Name 2',
        createdAt: '2026-02-19T00:00:00.000Z',
      );

      expect(t1, equals(t2));
      expect(t1.hashCode, t2.hashCode);
    });

    test('withDocumentIds creates new instance with updated IDs', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Test',
        documentIds: {'doc-1'},
        createdAt: '2026-02-18T00:00:00.000Z',
      );

      final updated = topic.withDocumentIds({'doc-2', 'doc-3'});

      expect(updated.documentIds, containsAll(['doc-2', 'doc-3']));
      expect(updated.documentIds, hasLength(2));
      // Original unchanged
      expect(topic.documentIds, hasLength(1));
    });

    test('withLastIngestedAt creates new instance', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Test',
        createdAt: '2026-02-18T00:00:00.000Z',
      );

      final updated = topic.withLastIngestedAt('2026-02-18T12:00:00.000Z');

      expect(updated.lastIngestedAt, '2026-02-18T12:00:00.000Z');
      expect(topic.lastIngestedAt, isNull);
    });

    test('full round-trip through JSON string', () {
      final topic = Topic(
        id: 'topic-1',
        name: 'Agent Skills',
        description: 'Course on agent skills',
        documentIds: {'doc-a', 'doc-b'},
        createdAt: '2026-02-18T00:00:00.000Z',
        lastIngestedAt: '2026-02-18T01:00:00.000Z',
      );

      final jsonStr = jsonEncode(topic.toJson());
      final restored =
          Topic.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.id, topic.id);
      expect(restored.name, topic.name);
      expect(restored.documentIds, topic.documentIds);
    });
  });
}
