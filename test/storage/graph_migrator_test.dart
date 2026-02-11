import 'dart:io';

import 'package:engram/src/models/concept.dart';
import 'package:engram/src/models/knowledge_graph.dart';
import 'package:engram/src/models/relationship.dart';
import 'package:engram/src/storage/firestore_graph_repository.dart';
import 'package:engram/src/storage/graph_migrator.dart';
import 'package:engram/src/storage/local_graph_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:test/test.dart';

void main() {
  group('GraphMigrator', () {
    test('migrates local → Firestore', () async {
      final tmpDir = Directory.systemTemp.createTempSync('engram_migrate_');
      final local = LocalGraphRepository(dataDir: tmpDir.path);
      final firestore = FirestoreGraphRepository(
        firestore: FakeFirebaseFirestore(),
        userId: 'test-user',
      );

      final graph = KnowledgeGraph(
        concepts: [
          Concept(
            id: 'c1',
            name: 'Docker',
            description: 'Container runtime',
            sourceDocumentId: 'doc1',
          ),
        ],
      );
      await local.save(graph);

      final migrator = GraphMigrator(source: local, destination: firestore);
      final result = await migrator.migrate();

      expect(result.concepts, hasLength(1));

      // Verify destination has the data
      final loaded = await firestore.load();
      expect(loaded.concepts, hasLength(1));
      expect(loaded.concepts.first.id, 'c1');

      tmpDir.deleteSync(recursive: true);
    });

    test('migrates graph with only relationships', () async {
      final tmpDir = Directory.systemTemp.createTempSync('engram_migrate_');
      final local = LocalGraphRepository(dataDir: tmpDir.path);
      final firestore = FirestoreGraphRepository(
        firestore: FakeFirebaseFirestore(),
        userId: 'test-user',
      );

      final graph = KnowledgeGraph(
        relationships: [
          const Relationship(
            id: 'r1',
            fromConceptId: 'c1',
            toConceptId: 'c2',
            label: 'depends on',
          ),
        ],
      );
      await local.save(graph);

      final migrator = GraphMigrator(source: local, destination: firestore);
      final result = await migrator.migrate();

      expect(result.relationships, hasLength(1));

      final loaded = await firestore.load();
      expect(loaded.relationships, hasLength(1));
      expect(loaded.relationships.first.id, 'r1');

      tmpDir.deleteSync(recursive: true);
    });

    test('skips migration for empty graph', () async {
      final tmpDir = Directory.systemTemp.createTempSync('engram_migrate_');
      final local = LocalGraphRepository(dataDir: tmpDir.path);
      final firestore = FirestoreGraphRepository(
        firestore: FakeFirebaseFirestore(),
        userId: 'test-user',
      );

      final migrator = GraphMigrator(source: local, destination: firestore);
      final result = await migrator.migrate();

      expect(result.concepts, isEmpty);

      tmpDir.deleteSync(recursive: true);
    });
  });
}
