import SwiftUI

/// Visual DAG rendering of workflow nodes.
///
/// Nodes are laid out top-to-bottom following the execution flow.
/// Edges are drawn between connected nodes. Colors reflect node type
/// and optionally run status.
struct WorkflowGraphView: View {
    let nodes: [WorkflowNode]
    let edges: [WorkflowEdge]
    @Binding var selectedNode: WorkflowNode?
    let runNodeStates: [String: NodeState]?
    let currentRunNode: String?

    // Layout constants
    private let nodeWidth: CGFloat = 180
    private let nodeHeight: CGFloat = 56
    private let horizontalSpacing: CGFloat = 60
    private let verticalSpacing: CGFloat = 40

    private var layout: DAGLayout {
        DAGLayout(nodes: nodes, edges: allEdges, nodeWidth: nodeWidth, nodeHeight: nodeHeight,
                  horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }

    /// Build comprehensive edge list from both explicit edges and on_success/on_failure references
    private var allEdges: [ResolvedEdge] {
        var result: [ResolvedEdge] = []
        let nodeIds = Set(nodes.map(\.id))

        // From explicit edges
        for edge in edges {
            if nodeIds.contains(edge.from) && nodeIds.contains(edge.to) {
                result.append(ResolvedEdge(from: edge.from, to: edge.to, kind: .normal, label: edge.condition))
            }
        }

        // From on_success / on_failure.fallback
        for node in nodes {
            if let onSuccess = node.onSuccess, nodeIds.contains(onSuccess) {
                // Avoid duplicate if already in explicit edges
                if !result.contains(where: { $0.from == node.id && $0.to == onSuccess && $0.kind == .normal }) {
                    result.append(ResolvedEdge(from: node.id, to: onSuccess, kind: .success, label: nil))
                }
            }
            if let fallback = node.onFailure?.fallback, nodeIds.contains(fallback) {
                result.append(ResolvedEdge(from: node.id, to: fallback, kind: .failure, label: "fail"))
            }
        }

        return result
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                // Draw edges first (behind nodes)
                ForEach(layout.edgeLines, id: \.id) { line in
                    EdgeLine(line: line)
                }

                // Draw nodes
                ForEach(nodes) { node in
                    if let pos = layout.positions[node.id] {
                        NodeChip(
                            node: node,
                            isSelected: selectedNode?.id == node.id,
                            isCurrentRunNode: currentRunNode == node.id,
                            runState: runNodeStates?[node.id]
                        )
                        .frame(width: nodeWidth, height: nodeHeight)
                        .position(x: pos.x + nodeWidth / 2, y: pos.y + nodeHeight / 2)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedNode = (selectedNode?.id == node.id) ? nil : node
                            }
                        }
                    }
                }
            }
            .frame(
                width: layout.canvasSize.width + 40,
                height: layout.canvasSize.height + 40
            )
            .padding(20)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

// MARK: - Resolved Edge

struct ResolvedEdge: Identifiable, Hashable {
    let from: String
    let to: String
    let kind: Kind
    let label: String?

    var id: String { "\(from)->\(to):\(kind.rawValue)" }

    enum Kind: String {
        case normal
        case success
        case failure
    }
}

// MARK: - DAG Layout Engine

struct DAGLayout {
    let positions: [String: CGPoint]
    let canvasSize: CGSize
    let edgeLines: [EdgeLineData]

    init(nodes: [WorkflowNode], edges: [ResolvedEdge], nodeWidth: CGFloat, nodeHeight: CGFloat,
         horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {

        // Build adjacency + compute layers via topological sort
        let nodeIds = nodes.map(\.id)
        let nodeSet = Set(nodeIds)
        var incoming: [String: Set<String>] = [:]
        var outgoing: [String: [String]] = [:]

        for id in nodeIds {
            incoming[id] = []
            outgoing[id] = []
        }

        for edge in edges where nodeSet.contains(edge.from) && nodeSet.contains(edge.to) {
            incoming[edge.to, default: []].insert(edge.from)
            outgoing[edge.from, default: []].append(edge.to)
        }

        // Assign layers (longest path from root)
        var layers: [String: Int] = [:]
        var visited: Set<String> = []

        func assignLayer(_ nodeId: String, layer: Int) {
            if let existing = layers[nodeId], existing >= layer {
                return
            }
            layers[nodeId] = layer
            visited.insert(nodeId)
            for next in (outgoing[nodeId] ?? []) {
                assignLayer(next, layer: layer + 1)
            }
        }

        // Start from nodes with no incoming edges
        let roots = nodeIds.filter { (incoming[$0] ?? []).isEmpty }
        if roots.isEmpty && !nodeIds.isEmpty {
            // Fallback: use first node
            assignLayer(nodeIds[0], layer: 0)
        } else {
            for root in roots {
                assignLayer(root, layer: 0)
            }
        }

        // Assign remaining unvisited nodes
        for id in nodeIds where layers[id] == nil {
            layers[id] = (layers.values.max() ?? 0) + 1
        }

        // Group by layer
        var layerGroups: [Int: [String]] = [:]
        for (id, layer) in layers {
            layerGroups[layer, default: []].append(id)
        }

        // Compute positions
        var pos: [String: CGPoint] = [:]
        let maxNodesInLayer = layerGroups.values.map(\.count).max() ?? 1
        let canvasWidth = CGFloat(maxNodesInLayer) * (nodeWidth + horizontalSpacing)

        for (layer, ids) in layerGroups {
            let sortedIds = ids.sorted()
            let layerWidth = CGFloat(sortedIds.count) * (nodeWidth + horizontalSpacing) - horizontalSpacing
            let xOffset = (canvasWidth - layerWidth) / 2

            for (i, id) in sortedIds.enumerated() {
                let x = xOffset + CGFloat(i) * (nodeWidth + horizontalSpacing)
                let y = CGFloat(layer) * (nodeHeight + verticalSpacing)
                pos[id] = CGPoint(x: x, y: y)
            }
        }

        self.positions = pos
        let maxLayer = layerGroups.keys.max() ?? 0
        self.canvasSize = CGSize(
            width: canvasWidth,
            height: CGFloat(maxLayer + 1) * (nodeHeight + verticalSpacing)
        )

        // Build edge lines
        var lines: [EdgeLineData] = []
        for edge in edges {
            guard let fromPos = pos[edge.from], let toPos = pos[edge.to] else { continue }
            let startPoint = CGPoint(x: fromPos.x + nodeWidth / 2, y: fromPos.y + nodeHeight)
            let endPoint = CGPoint(x: toPos.x + nodeWidth / 2, y: toPos.y)
            lines.append(EdgeLineData(
                id: edge.id,
                start: startPoint,
                end: endPoint,
                kind: edge.kind,
                label: edge.label
            ))
        }
        self.edgeLines = lines
    }
}

struct EdgeLineData: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
    let kind: ResolvedEdge.Kind
    let label: String?
}

// MARK: - Edge Line View

struct EdgeLine: View {
    let line: EdgeLineData

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: line.start)
                // Bezier curve for smooth edges
                let midY = (line.start.y + line.end.y) / 2
                path.addCurve(
                    to: line.end,
                    control1: CGPoint(x: line.start.x, y: midY),
                    control2: CGPoint(x: line.end.x, y: midY)
                )
            }
            .stroke(edgeColor, style: StrokeStyle(lineWidth: 2, dash: line.kind == .failure ? [5, 3] : []))

            // Arrow head
            arrowHead

            // Label
            if let label = line.label {
                Text(label)
                    .font(.system(size: 9).weight(.medium))
                    .foregroundColor(edgeColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.9))
                    .position(x: (line.start.x + line.end.x) / 2, y: (line.start.y + line.end.y) / 2)
            }
        }
    }

    private var edgeColor: Color {
        switch line.kind {
        case .success: return .green.opacity(0.6)
        case .failure: return .red.opacity(0.6)
        case .normal: return .secondary.opacity(0.5)
        }
    }

    private var arrowHead: some View {
        let angle = atan2(line.end.y - line.start.y, line.end.x - line.start.x)
        let arrowSize: CGFloat = 8
        return Path { path in
            let tip = line.end
            let left = CGPoint(
                x: tip.x - arrowSize * cos(angle - .pi / 6),
                y: tip.y - arrowSize * sin(angle - .pi / 6)
            )
            let right = CGPoint(
                x: tip.x - arrowSize * cos(angle + .pi / 6),
                y: tip.y - arrowSize * sin(angle + .pi / 6)
            )
            path.move(to: tip)
            path.addLine(to: left)
            path.addLine(to: right)
            path.closeSubpath()
        }
        .fill(edgeColor)
    }
}

// MARK: - Node Chip

struct NodeChip: View {
    let node: WorkflowNode
    let isSelected: Bool
    let isCurrentRunNode: Bool
    let runState: NodeState?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: nodeIcon)
                    .font(.caption)
                    .foregroundColor(nodeColor)
                Text(node.id)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Text(node.type)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)

            // Run status indicator
            if let state = runState {
                HStack(spacing: 3) {
                    Circle()
                        .fill(statusColor(state.status ?? "unknown"))
                        .frame(width: 6, height: 6)
                    Text(state.status ?? "—")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: isSelected ? 2.5 : 1)
        )
        .shadow(color: isCurrentRunNode ? .blue.opacity(0.5) : .clear, radius: 6)
        .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        if isSelected {
            return nodeColor.opacity(0.12)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected { return nodeColor }
        if isCurrentRunNode { return .blue }
        return .secondary.opacity(0.3)
    }

    private var nodeIcon: String {
        switch node.type {
        case "spawn_agent": return "person.crop.circle.badge.plus"
        case "send_to_session": return "paperplane.fill"
        case "tool_call": return "terminal"
        case "branch": return "arrow.triangle.branch"
        case "gate": return "hand.raised.fill"
        case "notify": return "bell.fill"
        case "cleanup": return "trash"
        case "python_call": return "chevron.left.forwardslash.chevron.right"
        case "for_each": return "arrow.3.trianglepath"
        case "sub_workflow": return "square.stack.3d.down.right"
        case "reflect": return "brain.head.profile"
        default: return "questionmark.circle"
        }
    }

    private var nodeColor: Color {
        switch node.type {
        case "spawn_agent": return .blue
        case "send_to_session": return .cyan
        case "tool_call": return .green
        case "branch": return .purple
        case "gate": return .orange
        case "notify": return .yellow
        case "cleanup": return .gray
        case "python_call": return .indigo
        case "for_each": return .teal
        case "sub_workflow": return .pink
        case "reflect": return .mint
        default: return .gray
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "failed": return .red
        case "running": return .blue
        case "pending": return .gray
        default: return .gray
        }
    }
}
