import SwiftUI

struct WorkflowGraphView: View {
    let nodes: [WorkflowNode]
    let edges: [WorkflowEdge]
    @Binding var selectedNode: WorkflowNode?
    let runNodeStates: [String: NodeState]?
    let currentRunNode: String?

    @State private var zoom: CGFloat = 1.0
    @State private var hideUnrelated: Bool = false

    private let nodeWidth: CGFloat = 220
    private let nodeHeight: CGFloat = 168
    private let horizontalSpacing: CGFloat = 92
    private let verticalSpacing: CGFloat = 34

    private var layout: DAGLayout {
        DAGLayout(nodes: nodes, edges: allEdges, nodeWidth: nodeWidth, nodeHeight: nodeHeight, horizontalSpacing: horizontalSpacing, verticalSpacing: verticalSpacing)
    }

    private var allEdges: [ResolvedEdge] {
        var result: [ResolvedEdge] = []
        let nodeIds = Set(nodes.map(\.id))

        for edge in edges where nodeIds.contains(edge.from) && nodeIds.contains(edge.to) {
            result.append(ResolvedEdge(from: edge.from, to: edge.to, kind: .normal, label: edge.condition))
        }

        for node in nodes {
            if let onSuccess = node.onSuccess,
               nodeIds.contains(onSuccess),
               !result.contains(where: { $0.from == node.id && $0.to == onSuccess }) {
                result.append(ResolvedEdge(from: node.id, to: onSuccess, kind: .success, label: "success"))
            }
            if let fallback = node.onFailure?.fallback, nodeIds.contains(fallback) {
                result.append(ResolvedEdge(from: node.id, to: fallback, kind: .failure, label: "failure"))
            }
        }
        return result
    }

    private var selectedConnections: Set<String> {
        guard let selected = selectedNode else { return [] }
        var related: Set<String> = [selected.id]
        for edge in allEdges where edge.from == selected.id || edge.to == selected.id {
            related.insert(edge.from)
            related.insert(edge.to)
        }
        return related
    }

    private var nodeConnections: [String: WorkflowNodeConnections] {
        WorkflowConnectionSummary.build(nodes: nodes, edges: allEdges)
    }

    private var nodeLabelsById: [String: String] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, NodeChip.shortNodeLabel(for: $0.id)) })
    }

    var body: some View {
        VStack(spacing: 8) {
            controlBar

            ScrollView([.horizontal, .vertical]) {
                canvas
                    .scaleEffect(zoom, anchor: .topLeading)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoom = min(2.2, max(0.55, value * zoom))
                    }
            )
        }
    }

    private var controlBar: some View {
        HStack(spacing: 8) {
            Label("Zoom", systemImage: "plus.magnifyingglass")
                .font(.caption)
                .foregroundColor(.secondary)

            Button { zoom = min(2.2, zoom + 0.1) } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button { zoom = max(0.55, zoom - 0.1) } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Fit") { zoom = 1.0 }
                .buttonStyle(.bordered)
                .controlSize(.small)

            Divider().frame(height: 14)

            Toggle(isOn: $hideUnrelated) {
                Text("Collapse unrelated")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .disabled(selectedNode == nil)

            Spacer()

            Text("\(Int(zoom * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layout.lanes, id: \.stage) { lane in
                StageLaneBackground(lane: lane)
            }

            ForEach(layout.edgeLines, id: \.id) { line in
                let isConnected = selectedNode != nil && line.connects(nodeId: selectedNode!.id)
                let shouldDim = selectedNode != nil && !isConnected
                let shouldHide = hideUnrelated && selectedNode != nil && !isConnected
                if !shouldHide {
                    EdgeLine(line: line, isHighlighted: selectedNode == nil || isConnected, isDimmed: shouldDim)
                }
            }

            ForEach(layout.stageHeaders, id: \.stage) { header in
                StageHeaderView(header: header)
                    .position(x: header.centerX, y: 18)
            }

            ForEach(nodes) { node in
                if let pos = layout.positions[node.id] {
                    let unrelated = selectedNode != nil && !selectedConnections.contains(node.id)
                    if !(hideUnrelated && unrelated) {
                        NodeChip(
                            node: node,
                            connections: nodeConnections[node.id] ?? .empty,
                            nodeLabelsById: nodeLabelsById,
                            isSelected: selectedNode?.id == node.id,
                            isCurrentRunNode: currentRunNode == node.id,
                            runState: runNodeStates?[node.id],
                            isDimmed: unrelated
                        )
                        .frame(width: nodeWidth, height: nodeHeight)
                        .position(x: pos.x + nodeWidth / 2, y: pos.y + nodeHeight / 2)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                selectedNode = (selectedNode?.id == node.id) ? nil : node
                            }
                        }
                    }
                }
            }

            if let node = selectedNode, let pos = layout.positions[node.id] {
                NodeDetailCard(node: node, runState: runNodeStates?[node.id])
                    .padding(12)
                    .frame(width: 360)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    .position(detailPosition(for: pos))
            }

            LegendView()
                .position(x: layout.canvasSize.width - 120, y: 30)
        }
        .frame(width: layout.canvasSize.width + 80, height: layout.canvasSize.height + 70)
    }

    private func detailPosition(for nodePos: CGPoint) -> CGPoint {
        let rightCandidate = nodePos.x + nodeWidth + 220
        let x: CGFloat = rightCandidate < layout.canvasSize.width ? rightCandidate : max(220, nodePos.x - 200)
        let y: CGFloat = max(130, min(layout.canvasSize.height - 120, nodePos.y + nodeHeight / 2))
        return CGPoint(x: x, y: y)
    }
}

struct ResolvedEdge: Identifiable, Hashable {
    let from: String
    let to: String
    let kind: Kind
    let label: String?
    var id: String { "\(from)->\(to):\(kind.rawValue):\(label ?? "")" }
    enum Kind: String { case normal, success, failure }
}

struct WorkflowNodeConnections: Equatable {
    let incoming: [String]
    let outgoing: [String]

    static let empty = WorkflowNodeConnections(incoming: [], outgoing: [])
}

enum WorkflowConnectionSummary {
    static func build(nodes: [WorkflowNode], edges: [ResolvedEdge]) -> [String: WorkflowNodeConnections] {
        let nodeIds = Set(nodes.map(\.id))
        var incoming: [String: Set<String>] = [:]
        var outgoing: [String: Set<String>] = [:]

        for nodeId in nodeIds {
            incoming[nodeId] = []
            outgoing[nodeId] = []
        }

        for edge in edges where nodeIds.contains(edge.from) && nodeIds.contains(edge.to) {
            incoming[edge.to, default: []].insert(edge.from)
            outgoing[edge.from, default: []].insert(edge.to)
        }

        return Dictionary(uniqueKeysWithValues: nodeIds.map { nodeId in
            let inList = Array(incoming[nodeId, default: []]).sorted()
            let outList = Array(outgoing[nodeId, default: []]).sorted()
            return (nodeId, WorkflowNodeConnections(incoming: inList, outgoing: outList))
        })
    }
}

struct DAGLayout {
    let positions: [String: CGPoint]
    let canvasSize: CGSize
    let edgeLines: [EdgeLineData]
    let stageHeaders: [StageHeader]
    let lanes: [StageLane]

    init(nodes: [WorkflowNode], edges: [ResolvedEdge], nodeWidth: CGFloat, nodeHeight: CGFloat,
         horizontalSpacing: CGFloat, verticalSpacing: CGFloat) {
        let nodeIds = nodes.map(\.id)
        let nodeSet = Set(nodeIds)
        var incoming: [String: Set<String>] = [:]
        var outgoing: [String: [String]] = [:]

        for id in nodeIds { incoming[id] = []; outgoing[id] = [] }
        for edge in edges where nodeSet.contains(edge.from) && nodeSet.contains(edge.to) {
            incoming[edge.to, default: []].insert(edge.from)
            outgoing[edge.from, default: []].append(edge.to)
        }

        var stages: [String: Int] = [:]
        func assign(_ nodeId: String, _ stage: Int) {
            if let existing = stages[nodeId], existing >= stage { return }
            stages[nodeId] = stage
            for next in (outgoing[nodeId] ?? []) { assign(next, stage + 1) }
        }
        let roots = nodeIds.filter { (incoming[$0] ?? []).isEmpty }
        if roots.isEmpty, let first = nodeIds.first { assign(first, 0) }
        for root in roots { assign(root, 0) }
        for id in nodeIds where stages[id] == nil { stages[id] = (stages.values.max() ?? 0) + 1 }

        var stageGroups: [Int: [String]] = [:]
        for (id, stage) in stages { stageGroups[stage, default: []].append(id) }

        let maxStage = stageGroups.keys.max() ?? 0
        let maxRows = stageGroups.values.map(\.count).max() ?? 1
        let width = CGFloat(maxStage + 1) * (nodeWidth + horizontalSpacing)
        let height = CGFloat(maxRows) * (nodeHeight + verticalSpacing) + 60

        var pos: [String: CGPoint] = [:]
        var headers: [StageHeader] = []
        var stageLanes: [StageLane] = []

        for stage in 0...maxStage {
            let ids = (stageGroups[stage] ?? []).sorted()
            let stageHeight = CGFloat(ids.count) * (nodeHeight + verticalSpacing) - verticalSpacing
            let yOffset = max(46, (height - stageHeight) / 2)
            let x = CGFloat(stage) * (nodeWidth + horizontalSpacing)

            for (i, id) in ids.enumerated() {
                let y = yOffset + CGFloat(i) * (nodeHeight + verticalSpacing)
                pos[id] = CGPoint(x: x, y: y)
            }

            headers.append(StageHeader(stage: stage, count: ids.count, centerX: x + nodeWidth / 2))
            stageLanes.append(StageLane(stage: stage, rect: CGRect(x: x - 14, y: 30, width: nodeWidth + 28, height: height - 12)))
        }

        self.positions = pos
        self.canvasSize = CGSize(width: width, height: height)
        self.stageHeaders = headers
        self.lanes = stageLanes

        var lines: [EdgeLineData] = []
        for edge in edges {
            guard let fromPos = pos[edge.from], let toPos = pos[edge.to] else { continue }
            lines.append(EdgeLineData(id: edge.id, from: edge.from, to: edge.to, start: CGPoint(x: fromPos.x + nodeWidth, y: fromPos.y + nodeHeight / 2), end: CGPoint(x: toPos.x, y: toPos.y + nodeHeight / 2), kind: edge.kind, label: edge.label))
        }
        self.edgeLines = lines
    }
}

struct StageHeader { let stage: Int; let count: Int; let centerX: CGFloat }
struct StageLane { let stage: Int; let rect: CGRect }

struct EdgeLineData: Identifiable {
    let id: String
    let from: String
    let to: String
    let start: CGPoint
    let end: CGPoint
    let kind: ResolvedEdge.Kind
    let label: String?
    func connects(nodeId: String) -> Bool { from == nodeId || to == nodeId }
}

private struct StageLaneBackground: View {
    let lane: StageLane
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.secondary.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
            .frame(width: lane.rect.width, height: lane.rect.height)
            .position(x: lane.rect.midX, y: lane.rect.midY)
    }
}

private struct StageHeaderView: View {
    let header: StageHeader
    var body: some View {
        Text("Stage \(header.stage + 1) · \(header.count) node\(header.count == 1 ? "" : "s")")
            .font(.caption2.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
    }
}

struct EdgeLine: View {
    let line: EdgeLineData
    let isHighlighted: Bool
    let isDimmed: Bool

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: line.start)
                let elbowX = (line.start.x + line.end.x) / 2
                path.addLine(to: CGPoint(x: elbowX, y: line.start.y))
                path.addLine(to: CGPoint(x: elbowX, y: line.end.y))
                path.addLine(to: line.end)
            }
            .stroke(edgeColor, style: StrokeStyle(lineWidth: isHighlighted ? 2.4 : 1.6, dash: line.kind == .failure ? [6, 4] : []))
            .opacity(isDimmed ? 0.22 : 1)

            Image(systemName: "arrowtriangle.right.fill")
                .font(.system(size: 8))
                .foregroundColor(edgeColor)
                .position(x: line.end.x - 4, y: line.end.y)
                .opacity(isDimmed ? 0.25 : 1)

            if let label = line.label {
                Text(label)
                    .font(.system(size: 9).weight(.medium))
                    .foregroundColor(edgeColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
                    .clipShape(Capsule())
                    .position(x: (line.start.x + line.end.x) / 2, y: min(line.start.y, line.end.y) - 8)
                    .opacity(isDimmed ? 0.25 : 1)
            }
        }
    }

    private var edgeColor: Color {
        switch line.kind {
        case .success: return .green.opacity(0.8)
        case .failure: return .red.opacity(0.8)
        case .normal: return .blue.opacity(0.72)
        }
    }
}

private struct LegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            row("Normal", .secondary)
            row("Success", .green)
            row("Failure", .red)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
    }

    private func row(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}

struct NodeChip: View {
    let node: WorkflowNode
    let connections: WorkflowNodeConnections
    let nodeLabelsById: [String: String]
    let isSelected: Bool
    let isCurrentRunNode: Bool
    let runState: NodeState?
    let isDimmed: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: nodeIcon).font(.caption).foregroundColor(nodeColor)
                Text(node.id).font(.caption.weight(.semibold)).lineLimit(1)
            }

            Text(node.type)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text(Self.connectionSummary(incoming: connections.incoming.count, outgoing: connections.outgoing.count))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 5) {
                connectionRow(title: "To", symbol: "arrowshape.right.fill", ids: connections.outgoing, color: .green.opacity(0.9))
                connectionRow(title: "From", symbol: "arrowshape.left.fill", ids: connections.incoming, color: .blue.opacity(0.9))
            }
            .font(.system(size: 10))
            .frame(maxWidth: .infinity, alignment: .leading)

            if let state = runState {
                HStack(spacing: 4) {
                    Circle().fill(statusColor(state.status ?? "unknown")).frame(width: 6, height: 6)
                    Text(state.status ?? "—").font(.system(size: 8)).foregroundColor(.secondary)
                    if let attempts = state.attempts, attempts > 1 {
                        Text("×\(attempts)").font(.system(size: 8, weight: .semibold)).foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? nodeColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? nodeColor : (isCurrentRunNode ? .blue : .secondary.opacity(0.3)), lineWidth: isSelected ? 2.5 : 1))
        .shadow(color: isCurrentRunNode ? .blue.opacity(0.35) : .clear, radius: 5)
        .opacity(isDimmed ? 0.35 : 1)
    }

    private func connectionRow(title: String, symbol: String, ids: [String], color: Color) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .padding(.top, 2)
            Text("\(title):")
                .fontWeight(.semibold)

            Text(Self.connectionPreviewText(ids: ids, nodeLabelsById: nodeLabelsById, limit: Self.connectionTokenPreviewLimit))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundColor(color)
    }

    static let connectionTokenPreviewLimit = 5

    static func connectionSummary(incoming: Int, outgoing: Int) -> String {
        "\(incoming) in · \(outgoing) out"
    }

    static func connectionTokens(ids: [String], nodeLabelsById: [String: String], limit: Int) -> [String] {
        ids.prefix(limit).map { nodeLabelsById[$0] ?? shortNodeLabel(for: $0) }
    }

    static func connectionPreviewText(ids: [String], nodeLabelsById: [String: String], limit: Int) -> String {
        guard !ids.isEmpty else { return "none" }
        let tokens = connectionTokens(ids: ids, nodeLabelsById: nodeLabelsById, limit: limit)
        if ids.count > limit {
            return tokens.joined(separator: ", ") + " +\(ids.count - limit)"
        }
        return tokens.joined(separator: ", ")
    }

    static func shortNodeLabel(for id: String) -> String {
        if id.count <= 10 { return id }
        return String(id.prefix(4)) + "…" + String(id.suffix(3))
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
