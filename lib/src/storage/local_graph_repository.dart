import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/knowledge_graph.dart';
import 'graph_repository.dart';

class LocalGraphRepository extends GraphRepository {
  LocalGraphRepository({required String dataDir}) : _dataDir = dataDir;

  final String _dataDir;

  String get _filePath => p.join(_dataDir, 'knowledge_graph.json');

  @override
  Future<KnowledgeGraph> load() async {
    final file = File(_filePath);
    if (!file.existsSync()) {
      return KnowledgeGraph.empty;
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return KnowledgeGraph.empty;
    }
    final json = jsonDecode(content) as Map<String, dynamic>;
    return KnowledgeGraph.fromJson(json);
  }

  /// Atomic save: write to temp file, then rename.
  @override
  Future<void> save(KnowledgeGraph graph) async {
    final dir = Directory(_dataDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final json = const JsonEncoder.withIndent('  ').convert(graph.toJson());
    final tmpFile = File('$_filePath.tmp');
    await tmpFile.writeAsString(json);
    await tmpFile.rename(_filePath);
  }

  @override
  Stream<KnowledgeGraph> watch() async* {
    yield await load();
  }
}
