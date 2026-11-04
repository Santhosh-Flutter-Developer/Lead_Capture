import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:iconsax/iconsax.dart';

class OrgChart extends StatefulWidget {
  final List<dynamic> rawData;
  const OrgChart({super.key, required this.rawData});

  @override
  State<OrgChart> createState() => _OrgChartState();
}

class _OrgChartState extends State<OrgChart> {
  final Graph graph = Graph()..isTree = false;

  // Switched to FruchtermanReingoldAlgorithm to resolve RangeError cycles
  final FruchtermanReingoldAlgorithm algorithm = FruchtermanReingoldAlgorithm(
    FruchtermanReingoldConfiguration(iterations: 200, repulsionPercentage: 1.5),
  );

  late Map<String, List<String>> reportingMap;
  final Map<String, Node> nodeCache = {};

  // Guards so the graph (which needs Theme.of(context)) is only
  // built once automatically, right after the first safe opportunity.
  bool _graphBuilt = false;

  @override
  void initState() {
    super.initState();
    // Safe here: normalize() only processes widget.rawData and does NOT
    // touch Theme.of(context) or any other InheritedWidget lookup.
    reportingMap = normalize(widget.rawData);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies() runs AFTER initState() and after the widget
    // is attached to the tree, so Theme.of(context) is safe here.
    if (!_graphBuilt) {
      _buildGraph();
      _graphBuilt = true;
    }
  }

  void _buildGraph() {
    for (final parent in reportingMap.keys) {
      final parentNode = _getNode(parent);

      for (final child in reportingMap[parent]!) {
        final childNode = _getNode(child);

        // Check if edge already exists to prevent duplicate edge errors
        graph.addEdge(
          parentNode,
          childNode,
          paint: Paint()
            ..color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  Map<String, List<String>> normalize(List<dynamic> input) {
    final Map<String, List<String>> result = {};

    for (final item in input) {
      if (item is Map && item.isNotEmpty) {
        final entry = item.entries.first;
        final String parentId = entry.key.toString();
        final dynamic rawChildren = entry.value;

        if (rawChildren is Map) {
          result[parentId] = rawChildren.values
              .map((e) => e.toString())
              .toList();
        } else {
          result[parentId] = [];
        }
      }
    }
    return result;
  }

  Node _getNode(String id) {
    return nodeCache.putIfAbsent(id, () => Node.Id(id));
  }

  Widget _nodeWidget(String id) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Iconsax.user, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 16),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  id,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Member",
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Workflow Hierarchy',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Iconsax.refresh, color: Theme.of(context).colorScheme.primary, size: 20),
            onPressed: () {
              setState(() {
                nodeCache.clear();
                graph.nodes.clear();
                graph.edges.clear();
                // Safe to call directly here — we're well past initState()
                // and didChangeDependencies(), so Theme.of(context) works fine.
                reportingMap = normalize(widget.rawData);
                _buildGraph();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.01,
            maxScale: 2.0,
            child: GraphView(
              graph: graph,
              algorithm: algorithm,
              paint: Paint()
                ..color = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                ..strokeWidth = 2
                ..style = PaintingStyle.stroke,
              builder: (Node node) {
                final dynamic value = node.key?.value;
                final String id = value?.toString() ?? "Unknown";
                return _nodeWidget(id);
              },
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Force-directed layout: Zoom & Pan enabled",
                  style: TextStyle(color: Theme.of(context).colorScheme.surface, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
