import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../engine/force_directed_layout.dart';
import '../../engine/graph_analyzer.dart';
import '../../engine/mastery_state.dart';
import '../../models/knowledge_graph.dart';
import '../../models/network_health.dart';
import 'catastrophe_painter.dart';
import 'edge_panel.dart';
import 'graph_edge.dart';
import 'graph_node.dart';
import 'graph_painter.dart';
import 'particle_system.dart';
import 'relay_pulse_painter.dart';
import 'storm_overlay_painter.dart';
import 'team_avatar_cache.dart';
import 'team_node.dart';

/// Interactive force-directed graph visualization.
///
/// Renders concept nodes with mastery coloring and optional team member avatars.
/// The layout settles (ticker stops) so `pumpAndSettle()` works in tests.
class ForceDirectedGraphWidget extends StatefulWidget {
  const ForceDirectedGraphWidget({
    required this.graph,
    this.teamNodes = const [],
    this.healthTier = HealthTier.healthy,
    this.guardianMap = const {},
    this.currentUserUid,
    this.isStormActive = false,
    this.relayPulses = const [],
    this.relayConceptIds = const {},
    this.onDebugTick,
    this.layoutWidth,
    this.layoutHeight,
    super.key,
  });

  final KnowledgeGraph graph;

  /// Layout canvas width. When null, defaults to 800.
  final double? layoutWidth;

  /// Layout canvas height. When null, defaults to 600.
  final double? layoutHeight;

  /// Team member nodes to render alongside concepts. Each team node is
  /// connected to its mastered concepts with weaker spring forces.
  final List<TeamNode> teamNodes;

  /// Current network health tier — drives catastrophe visual effects.
  final HealthTier healthTier;

  /// Maps concept ID → guardian UID for shield badge rendering.
  final Map<String, String> guardianMap;

  /// Current user's UID — their guarded nodes get a gold ring.
  final String? currentUserUid;

  /// Whether an entropy storm is currently active (enables storm overlay).
  final bool isStormActive;

  /// Active relay pulses traveling along edges.
  final List<RelayPulse> relayPulses;

  /// Concept IDs in active relays — highlighted with cyan ring.
  final Set<String> relayConceptIds;

  /// Optional callback fired each animation tick with layout debug info.
  /// Used by GraphLabScreen to display temperature, pinned count, etc.
  final void Function(double temperature, int pinnedCount, int totalCount,
      bool isSettled)? onDebugTick;

  @override
  State<ForceDirectedGraphWidget> createState() =>
      _ForceDirectedGraphWidgetState();
}

class _ForceDirectedGraphWidgetState extends State<ForceDirectedGraphWidget>
    with TickerProviderStateMixin {
  late ForceDirectedLayout _layout;
  List<GraphNode> _nodes = [];
  late List<GraphEdge> _edges;
  late Ticker _ticker;

  final _transformController = TransformationController();
  final _avatarCache = TeamAvatarCache();
  String? _selectedNodeId;
  OverlayEntry? _overlayEntry;

  /// Index of the node currently being dragged, or null.
  int? _draggingNodeIndex;

  /// Offset into the layout positions list where team nodes begin.
  int _teamNodeStartIndex = 0;

  // Catastrophe visual system
  late final AnimationController _catastropheController;
  final ParticleSystem _particleSystem = ParticleSystem();
  bool _catastropheActive = false;

  // Storm visual system
  late final AnimationController _stormController;
  bool _stormActive = false;

  @override
  void initState() {
    super.initState();
    _buildGraph();
    _ticker = createTicker(_onTick)..start();

    _catastropheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(_onCatastropheFrame);

    _stormController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        if (_stormActive) setState(() {});
      });

    _initCatastropheEffects();
    _initStormEffects();
  }

  @override
  void didUpdateWidget(ForceDirectedGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph != widget.graph ||
        oldWidget.teamNodes != widget.teamNodes ||
        oldWidget.layoutWidth != widget.layoutWidth ||
        oldWidget.layoutHeight != widget.layoutHeight) {
      _removeOverlay();
      _buildGraph();
      if (!_ticker.isActive) _ticker.start();
    }
    if (oldWidget.healthTier != widget.healthTier) {
      _initCatastropheEffects();
    }
    if (oldWidget.isStormActive != widget.isStormActive) {
      _initStormEffects();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _stormController.dispose();
    _catastropheController.dispose();
    _ticker.dispose();
    _transformController.dispose();
    _avatarCache.dispose();
    super.dispose();
  }

  void _initCatastropheEffects() {
    final tier = widget.healthTier;
    if (tier == HealthTier.healthy) {
      _catastropheActive = false;
      _catastropheController.stop();
      _catastropheController.reset();
    } else {
      _catastropheActive = true;
      _particleSystem.initialize(_edges, tier);
      _catastropheController.repeat();
    }
  }

  void _initStormEffects() {
    if (widget.isStormActive) {
      _stormActive = true;
      _stormController.repeat();
    } else {
      _stormActive = false;
      _stormController.stop();
      _stormController.reset();
    }
  }

  void _onCatastropheFrame() {
    if (!_catastropheActive) return;
    _particleSystem.step(widget.healthTier);
    setState(() {});
  }

  void _buildGraph() {
    // A graph rebuild invalidates any in-progress drag.
    _draggingNodeIndex = null;

    // Preserve settled positions so incremental updates don't reset the layout.
    final oldPositions = <String, Offset>{};
    for (final node in _nodes) {
      oldPositions[node.id] = node.position;
    }

    final graph = widget.graph;
    final analyzer = GraphAnalyzer(graph);

    // Build concept nodes
    _nodes = <GraphNode>[];
    final nodeIndex = <String, int>{};

    for (var i = 0; i < graph.concepts.length; i++) {
      final concept = graph.concepts[i];
      final state = masteryStateOf(concept.id, graph, analyzer);
      final freshness = freshnessOf(concept.id, graph);
      _nodes.add(GraphNode(
        concept: concept,
        masteryState: state,
        freshness: freshness,
      ));
      nodeIndex[concept.id] = i;
    }

    // Build concept edges
    _edges = <GraphEdge>[];
    final layoutEdges = <(int, int)>[];

    for (final rel in graph.relationships) {
      final srcIdx = nodeIndex[rel.fromConceptId];
      final tgtIdx = nodeIndex[rel.toConceptId];
      if (srcIdx == null || tgtIdx == null) continue;
      _edges.add(GraphEdge(
        relationship: rel,
        source: _nodes[srcIdx],
        target: _nodes[tgtIdx],
      ));
      layoutEdges.add((srcIdx, tgtIdx));
    }

    // Add team nodes to the layout simulation.
    // They get indices after concept nodes, with edges connecting them to
    // mastered concepts. These use the same force simulation but the layout
    // engine treats all edges equally — the weaker visual appearance is
    // handled in the painter.
    _teamNodeStartIndex = _nodes.length;
    final teamNodes = widget.teamNodes;

    for (var i = 0; i < teamNodes.length; i++) {
      final teamIdx = _teamNodeStartIndex + i;

      // Connect team node to each concept they've mastered
      for (final conceptId in teamNodes[i].masteredConceptIds) {
        final conceptIdx = nodeIndex[conceptId];
        if (conceptIdx != null) {
          layoutEdges.add((teamIdx, conceptIdx));
        }
      }

      // Pre-load avatar images
      final photoUrl = teamNodes[i].photoUrl;
      if (photoUrl != null) {
        _avatarCache.loadAvatar(
          uid: teamNodes[i].friend.uid,
          url: photoUrl,
          onLoaded: () {
            if (mounted) setState(() {});
          },
        );
      }
    }

    // Seed the layout with old positions for existing nodes so the graph
    // settles incrementally instead of jumping on every update.
    // Pinned nodes are immovable anchors — they exert forces but don't move.
    final totalCount = _nodes.length + teamNodes.length;
    final initialPositions = List<Offset?>.generate(totalCount, (i) {
      if (i < _nodes.length) return oldPositions[_nodes[i].id];
      return null; // team nodes get fresh positions — see #61
    });
    final hasOldPositions = initialPositions.any((p) => p != null);
    final pinnedIndices = <int>{
      for (var i = 0; i < _nodes.length; i++)
        if (oldPositions.containsKey(_nodes[i].id)) i,
    };

    _layout = ForceDirectedLayout(
      nodeCount: totalCount,
      edges: layoutEdges,
      width: widget.layoutWidth ?? 800.0,
      height: widget.layoutHeight ?? 600.0,
      seed: 42,
      initialPositions: hasOldPositions ? initialPositions : null,
      pinnedNodes: pinnedIndices.isNotEmpty ? pinnedIndices : null,
    );

    // Pre-settle: run ~1 second of simulation (60 steps at 60fps) before the
    // first paint so nodes are already spread out when they appear.
    for (var i = 0; i < 60; i++) {
      if (!_layout.step()) break;
    }

    _syncPositions();
  }

  void _onTick(Duration _) {
    final stillMoving = _layout.step();
    _syncPositions();
    setState(() {});
    if (!stillMoving) {
      _ticker.stop();
    }
    widget.onDebugTick?.call(
      _layout.temperature,
      _layout.pinnedCount,
      _layout.nodeCount,
      !stillMoving,
    );
  }

  void _syncPositions() {
    final positions = _layout.positions;
    for (var i = 0; i < _nodes.length; i++) {
      _nodes[i].position = positions[i];
    }
    // Sync team node positions
    final teamNodes = widget.teamNodes;
    for (var i = 0; i < teamNodes.length; i++) {
      teamNodes[i].position = positions[_teamNodeStartIndex + i];
    }
  }

  void _onTapUp(TapUpDetails details) {
    // GestureDetector is inside the InteractiveViewer, so localPosition
    // is already in content coordinates — no transform inversion needed.
    final localPoint = details.localPosition;

    // Check team nodes first (rendered on top)
    for (final teamNode in widget.teamNodes.reversed) {
      if (teamNode.containsPoint(localPoint)) {
        setState(() => _selectedNodeId = teamNode.id);
        _showTeamOverlay(teamNode, details.globalPosition);
        return;
      }
    }

    // Check concept nodes
    for (final node in _nodes.reversed) {
      if (node.containsPoint(localPoint)) {
        setState(() => _selectedNodeId = node.id);
        _showOverlay(node, details.globalPosition);
        return;
      }
    }

    // Check edges (relationships)
    const hitThreshold = 12.0;
    for (final edge in _edges) {
      if (_distanceToSegment(
              localPoint, edge.source.position, edge.target.position) <
          hitThreshold) {
        setState(() => _selectedNodeId = null);
        _showEdgeOverlay(edge, details.globalPosition);
        return;
      }
    }

    _removeOverlay();
    setState(() => _selectedNodeId = null);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final localPoint = details.localPosition;
    _removeOverlay();

    // Only concept nodes are draggable — team nodes represent other users
    // and should not be repositioned by the current user.
    for (var i = _nodes.length - 1; i >= 0; i--) {
      if (_nodes[i].containsPoint(localPoint)) {
        _draggingNodeIndex = i;
        _selectedNodeId = null;
        _layout.pinNode(i);
        // Restart the ticker if the simulation had settled
        if (!_ticker.isActive) _ticker.start();
        setState(() {});
        return;
      }
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    final idx = _draggingNodeIndex;
    if (idx == null) return;

    _layout.setNodePosition(idx, details.localPosition);
    _syncPositions();
    setState(() {});
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final idx = _draggingNodeIndex;
    if (idx == null) return;

    _layout.unpinNode(idx);
    _layout.reheat();
    _draggingNodeIndex = null;

    // Ensure the ticker is running so neighbors can re-settle
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _onLongPressCancel() {
    final idx = _draggingNodeIndex;
    if (idx == null) return;

    _layout.unpinNode(idx);
    _layout.reheat();
    _draggingNodeIndex = null;

    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  /// Perpendicular distance from [point] to the line segment [a]→[b].
  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSq < 0.001) return (point - a).distance;
    final t = ((point - a).dx * ab.dx + (point - a).dy * ab.dy) / lengthSq;
    final clamped = t.clamp(0.0, 1.0);
    final closest = Offset(a.dx + clamped * ab.dx, a.dy + clamped * ab.dy);
    return (point - closest).distance;
  }

  void _showOverlay(GraphNode node, Offset globalPosition) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: globalPosition.dx + 12,
        top: globalPosition.dy - 20,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: _NodePanel(node: node),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showTeamOverlay(TeamNode teamNode, Offset globalPosition) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: globalPosition.dx + 12,
        top: globalPosition.dy - 20,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: _TeamNodePanel(teamNode: teamNode),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _showEdgeOverlay(GraphEdge edge, Offset globalPosition) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: globalPosition.dx + 12,
        top: globalPosition.dy - 20,
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          child: EdgePanel(edge: edge),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final graphSize = Size(_layout.width, _layout.height);

    // Build layered painters from bottom to top:
    // 1. Base graph (GraphPainter)
    // 2. Storm overlay (when storm active)
    // 3. Catastrophe effects (when health tier > healthy)
    // 4. Particles (when catastrophe active)
    // 5. Relay pulses (when relays active)

    Widget child = SizedBox(width: graphSize.width, height: graphSize.height);

    // Layer 5: Relay pulses (topmost)
    if (widget.relayPulses.isNotEmpty) {
      child = CustomPaint(
        size: graphSize,
        painter: RelayPulsePainter(
          pulses: widget.relayPulses,
          edges: _edges,
          relayConceptIds: widget.relayConceptIds,
        ),
        child: child,
      );
    }

    // Layer 4: Particles
    if (_catastropheActive) {
      child = CustomPaint(
        size: graphSize,
        painter: ParticlePainter(
          particles: _particleSystem.particles,
          edges: _edges,
          tier: widget.healthTier,
        ),
        child: child,
      );
    }

    return InteractiveViewer(
      transformationController: _transformController,
      boundaryMargin: const EdgeInsets.all(200),
      minScale: 0.3,
      maxScale: 3.0,
      child: GestureDetector(
        onTapUp: _onTapUp,
        onLongPressStart: _onLongPressStart,
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd: _onLongPressEnd,
        onLongPressCancel: _onLongPressCancel,
        child: CustomPaint(
          size: graphSize,
          painter: GraphPainter(
            nodes: _nodes,
            edges: _edges,
            teamNodes: widget.teamNodes,
            avatarCache: _avatarCache,
            selectedNodeId: _selectedNodeId,
            draggingNodeId: _draggingNodeIndex != null
                ? _nodes[_draggingNodeIndex!].id
                : null,
            guardianMap: widget.guardianMap,
            currentUserUid: widget.currentUserUid,
          ),
          foregroundPainter: _catastropheActive
              ? CatastrophePainter(
                  nodes: _nodes,
                  edges: _edges,
                  tier: widget.healthTier,
                  animationProgress: _catastropheController.value,
                )
              : null,
          child: _stormActive
              ? CustomPaint(
                  size: graphSize,
                  painter: StormOverlayPainter(
                    edges: _edges,
                    animationProgress: _stormController.value,
                  ),
                  child: child,
                )
              : child,
        ),
      ),
    );
  }
}

/// Hover/tap card showing concept details.
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

/// Hover/tap card showing team member info.
class _TeamNodePanel extends StatelessWidget {
  const _TeamNodePanel({required this.teamNode});

  final TeamNode teamNode;

  @override
  Widget build(BuildContext context) {
    final snapshot = teamNode.detailedSnapshot;
    final healthPct = (teamNode.healthRatio * 100).round();
    final healthColor =
        Color.lerp(Colors.red, Colors.green, teamNode.healthRatio)!;

    return Card(
      elevation: 4,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundImage: teamNode.photoUrl != null
                      ? NetworkImage(teamNode.photoUrl!)
                      : null,
                  child: teamNode.photoUrl == null
                      ? Text(
                          teamNode.displayName.isNotEmpty
                              ? teamNode.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    teamNode.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$healthPct% health',
                  style: TextStyle(
                    fontSize: 11,
                    color: healthColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${snapshot.summary.mastered} mastered, '
              '${snapshot.summary.learning} learning',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (snapshot.summary.streak > 0) ...[
              const SizedBox(height: 2),
              Text(
                '${snapshot.summary.streak}-day streak',
                style: const TextStyle(fontSize: 10, color: Colors.amber),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

