import 'package:flutter/material.dart';

import '../../engine/force_directed_layout.dart';
import '../../engine/graph_analyzer.dart';
import '../../engine/mastery_state.dart';
import '../../models/knowledge_graph.dart';
import 'graph_edge.dart';
import 'graph_node.dart';
import 'graph_painter.dart';

/// A static (non-animated) knowledge graph visualization.
///
/// Runs [ForceDirectedLayout] to convergence synchronously, then renders the
/// result with [GraphPainter]. Supports pan/zoom via [InteractiveViewer] and
/// tap-to-inspect via overlay panels.
class StaticGraphWidget extends StatefulWidget {
  const StaticGraphWidget({required this.graph, super.key});

  final KnowledgeGraph graph;

  @override
  State<StaticGraphWidget> createState() => _StaticGraphWidgetState();
}

class _StaticGraphWidgetState extends State<StaticGraphWidget> {
  List<GraphNode> _nodes = const [];
  List<GraphEdge> _edges = const [];
  Size _graphSize = Size.zero;

  final _transformController = TransformationController();
  String? _selectedNodeId;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _computeLayout();
  }

  @override
  void didUpdateWidget(StaticGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph != widget.graph) {
      _removeOverlay();
      _computeLayout();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _transformController.dispose();
    super.dispose();
  }

  void _computeLayout() {
    final graph = widget.graph;
    if (graph.concepts.isEmpty) {
      _nodes = const [];
      _edges = const [];
      _graphSize = Size.zero;
      return;
    }

    final analyzer = GraphAnalyzer(graph);

    // Build nodes
    final nodes = <GraphNode>[];
    final nodeIndex = <String, int>{};
    for (var i = 0; i < graph.concepts.length; i++) {
      final concept = graph.concepts[i];
      nodes.add(GraphNode(
        concept: concept,
        masteryState: masteryStateOf(concept.id, graph, analyzer),
        freshness: freshnessOf(concept.id, graph),
      ));
      nodeIndex[concept.id] = i;
    }

    // Build edges
    final edges = <GraphEdge>[];
    final layoutEdges = <(int, int)>[];
    for (final rel in graph.relationships) {
      final srcIdx = nodeIndex[rel.fromConceptId];
      final tgtIdx = nodeIndex[rel.toConceptId];
      if (srcIdx == null || tgtIdx == null) continue;
      edges.add(GraphEdge(
        relationship: rel,
        source: nodes[srcIdx],
        target: nodes[tgtIdx],
      ));
      layoutEdges.add((srcIdx, tgtIdx));
    }

    // Run layout to convergence synchronously. Fine for current graph sizes
    // (10-40 concepts). For 200+ nodes, move to compute() Isolate — see #55.
    final layout = ForceDirectedLayout(
      nodeCount: nodes.length,
      edges: layoutEdges,
      seed: 42,
    );
    while (layout.step()) {}

    // Sync positions
    final positions = layout.positions;
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].position = positions[i];
    }

    _nodes = nodes;
    _edges = edges;
    _graphSize = Size(layout.width, layout.height);
  }

  void _onTapUp(TapUpDetails details) {
    final matrix = _transformController.value.clone()..invert();
    final localPoint =
        MatrixUtils.transformPoint(matrix, details.localPosition);

    // Check nodes first (they render on top of edges)
    for (final node in _nodes.reversed) {
      if (node.containsPoint(localPoint)) {
        setState(() => _selectedNodeId = node.id);
        _showNodeOverlay(node, details.globalPosition);
        return;
      }
    }

    // Check edges — touch target in logical pixels for edge tap detection
    const edgeTapThreshold = 12.0;
    for (final edge in _edges) {
      if (_distanceToSegment(localPoint, edge.source.position,
              edge.target.position) <
          edgeTapThreshold) {
        setState(() => _selectedNodeId = null);
        _showEdgeOverlay(edge, details.globalPosition);
        return;
      }
    }

    _removeOverlay();
    setState(() => _selectedNodeId = null);
  }

  /// Perpendicular distance from [point] to the line segment [a]→[b].
  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSq < 0.001) return (point - a).distance;
    // Project point onto the line, clamped to segment [0,1]
    final t = ((point - a).dx * ab.dx + (point - a).dy * ab.dy) / lengthSq;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + clamped * ab.dx, a.dy + clamped * ab.dy);
    return (point - closest).distance;
  }

  void _showNodeOverlay(GraphNode node, Offset globalPosition) {
    _removeOverlay();
    final clamped = _clampOverlayPosition(globalPosition);

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: clamped.dx,
        top: clamped.dy,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: _NodePanel(node: node),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showEdgeOverlay(GraphEdge edge, Offset globalPosition) {
    _removeOverlay();
    final clamped = _clampOverlayPosition(globalPosition);

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: clamped.dx,
        top: clamped.dy,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: _EdgePanel(edge: edge),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Clamp overlay position so the 250px panel stays on-screen.
  Offset _clampOverlayPosition(Offset globalPosition) {
    const panelWidth = 250.0;
    const panelHeight = 120.0; // approximate max height
    const margin = 12.0;
    final screen = MediaQuery.of(context).size;

    final left =
        (globalPosition.dx + margin + panelWidth > screen.width)
            ? globalPosition.dx - panelWidth - margin
            : globalPosition.dx + margin;
    final top =
        (globalPosition.dy - margin / 2 + panelHeight > screen.height)
            ? globalPosition.dy - panelHeight
            : globalPosition.dy - margin / 2;

    return Offset(left.clamp(0.0, screen.width - panelWidth),
        top.clamp(0.0, screen.height - panelHeight));
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
      return const Center(child: Text('No concepts to display'));
    }

    return GestureDetector(
      onTapUp: _onTapUp,
      child: InteractiveViewer(
        transformationController: _transformController,
        boundaryMargin: const EdgeInsets.all(200),
        minScale: 0.3,
        maxScale: 3.0,
        child: CustomPaint(
          size: _graphSize,
          painter: GraphPainter(
            nodes: _nodes,
            edges: _edges,
            selectedNodeId: _selectedNodeId,
          ),
        ),
      ),
    );
  }
}

/// Tap card showing concept details.
class _NodePanel extends StatelessWidget {
  const _NodePanel({required this.node});

  final GraphNode node;

  @override
  Widget build(BuildContext context) {
    final color = masteryColors[node.masteryState] ?? Colors.grey;
    final stateLabel = node.masteryState.name;

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    node.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (node.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                node.description,
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stateLabel[0].toUpperCase() + stateLabel.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (node.freshness < 1.0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${(node.freshness * 100).round()}% fresh',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tap card showing relationship details.
class _EdgePanel extends StatelessWidget {
  const _EdgePanel({required this.edge});

  final GraphEdge edge;

  @override
  Widget build(BuildContext context) {
    final color = edge.isDependency
        ? Colors.white.withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.6);

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  edge.isDependency ? Icons.arrow_forward : Icons.link,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    edge.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${edge.source.name}  \u2192  ${edge.target.name}',
              style: const TextStyle(fontSize: 12),
            ),
            if (edge.relationship.description != null) ...[
              const SizedBox(height: 4),
              Text(
                edge.relationship.description!,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (edge.isDependency) ...[
              const SizedBox(height: 4),
              Text(
                'Dependency',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
