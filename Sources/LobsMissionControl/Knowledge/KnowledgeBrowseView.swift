import SwiftUI

struct KnowledgeBrowseView: View {
    @ObservedObject var service: KnowledgeService
    let onSelectEntry: (KnowledgeEntry) -> Void
    
    @State private var typeFilter: KnowledgeType? = nil
    @State private var expandedCollections: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack(spacing: 12) {
                // Breadcrumb
                if let currentPath = service.currentPath {
                    HStack(spacing: 4) {
                        Button {
                            Task {
                                await service.browse(path: nil, type: typeFilter)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 11))
                                Text("Root")
                                    .font(.system(size: 12))
                            }
                        }
                        .buttonStyle(.borderless)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        
                        Text(currentPath)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11))
                        Text("All Knowledge")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                
                Spacer()
                
                // Type filter
                Menu {
                    Button("All Types") {
                        typeFilter = nil
                        Task {
                            await service.browse(path: service.currentPath, type: nil)
                        }
                    }
                    
                    Divider()
                    
                    ForEach(KnowledgeType.allCases, id: \.self) { type in
                        Button {
                            typeFilter = type
                            Task {
                                await service.browse(path: service.currentPath, type: type)
                            }
                        } label: {
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 12))
                        Text(typeFilter?.displayName ?? "All Types")
                            .font(.system(size: 12))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                LazyVStack(spacing: 8) {
                    if service.browseEntries.isEmpty {
                        emptyState
                    } else {
                        // Group by collections first, then regular entries by topic
                        let collections = service.browseEntries.filter { $0.isCollection }
                        let regularEntries = service.browseEntries.filter { !$0.isCollection }
                        
                        if !collections.isEmpty {
                            Section {
                                ForEach(collections) { collection in
                                    CollectionRow(
                                        collection: collection,
                                        service: service,
                                        isExpanded: expandedCollections.contains(collection.id),
                                        onToggle: {
                                            if expandedCollections.contains(collection.id) {
                                                expandedCollections.remove(collection.id)
                                            } else {
                                                expandedCollections.insert(collection.id)
                                                Task {
                                                    await service.browse(path: collection.path, type: typeFilter)
                                                }
                                            }
                                        },
                                        onSelectEntry: onSelectEntry
                                    )
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    Text("Collections")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                        }
                        
                        if !regularEntries.isEmpty {
                            // Group regular entries by topic
                            let groupedByTopic = Dictionary(grouping: regularEntries) { entry in
                                extractTopic(from: entry.path)
                            }
                            let sortedTopics = groupedByTopic.keys.sorted()
                            
                            ForEach(sortedTopics, id: \.self) { topic in
                                Section {
                                    ForEach(groupedByTopic[topic] ?? []) { entry in
                                        KnowledgeEntryRow(
                                            entry: entry,
                                            onSelect: { onSelectEntry(entry) }
                                        )
                                        .padding(.horizontal)
                                    }
                                } header: {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.blue)
                                        Text(formatTopicName(topic))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                        
                                        Text("\(groupedByTopic[topic]?.count ?? 0)")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, collections.isEmpty && topic == sortedTopics.first ? 8 : 16)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("No entries here")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if typeFilter != nil {
                Text("Try removing the type filter")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    /// Extract topic from path (e.g., "research/ai-agents/doc.md" → "ai-agents")
    private func extractTopic(from path: String) -> String {
        let components = path.split(separator: "/").map(String.init)
        
        // If path is like "research/<topic>/<file>", extract the topic
        if components.count >= 2 {
            // Skip first component (research/design/etc) and get second
            return components[1]
        }
        
        // If path is like "<topic>/<file>", use first component
        if components.count >= 1 {
            return components[0]
        }
        
        return "Other"
    }
    
    /// Format topic name for display (e.g., "ai-agents" → "AI Agents")
    private func formatTopicName(_ topic: String) -> String {
        topic
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

// MARK: - Collection Row

private struct CollectionRow: View {
    let collection: KnowledgeEntry
    @ObservedObject var service: KnowledgeService
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelectEntry: (KnowledgeEntry) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    // Folder icon
                    Image(systemName: isExpanded ? "folder.fill.badge.minus" : "folder.fill.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(collection.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                        
                        if let summary = collection.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(typeColor(collection.type))
                                    .frame(width: 6, height: 6)
                                Text(collection.type.displayName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            
                            if !collection.tags.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.system(size: 9))
                                    Text(collection.tags.prefix(2).joined(separator: ", "))
                                        .lineLimit(1)
                                }
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            Text(collection.fileUpdatedAt, style: .relative)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isHovering ? Color.blue.opacity(0.05) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovering ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }
            .padding(.horizontal)
            
            // Expanded content
            if isExpanded {
                let childEntries = service.browseEntries.filter { $0.parentPath == collection.path && $0.id != collection.id }
                
                if !childEntries.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(childEntries) { entry in
                            KnowledgeEntryRow(
                                entry: entry,
                                onSelect: { onSelectEntry(entry) }
                            )
                            .padding(.leading, 32)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
        }
    }
    
    private func typeColor(_ type: KnowledgeType) -> Color {
        switch type {
        case .research: return .blue
        case .doc: return .green
        case .design: return .purple
        case .decision: return .orange
        }
    }
}
