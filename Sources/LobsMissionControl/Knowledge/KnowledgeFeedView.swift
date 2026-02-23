import SwiftUI

struct KnowledgeFeedView: View {
    let entries: [KnowledgeEntry]
    let onSelectEntry: (KnowledgeEntry) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if entries.isEmpty {
                    emptyState
                } else {
                    ForEach(entries) { entry in
                        KnowledgeEntryRow(
                            entry: entry,
                            onSelect: { onSelectEntry(entry) }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("No recent knowledge entries")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("New research and documents will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - Knowledge Entry Row

struct KnowledgeEntryRow: View {
    let entry: KnowledgeEntry
    let onSelect: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                // Type icon
                Image(systemName: entry.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(typeColor(entry.type))
                    .frame(width: 32, height: 32)
                    .background(typeColor(entry.type).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title with collection indicator
                    HStack(spacing: 6) {
                        if entry.isCollection {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(entry.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                    }
                    
                    // Summary
                    if let summary = entry.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    
                    // Metadata row
                    HStack(spacing: 12) {
                        // Type badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(typeColor(entry.type))
                                .frame(width: 6, height: 6)
                            Text(entry.type.displayName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        // Tags
                        if !entry.tags.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 9))
                                Text(entry.tags.prefix(3).joined(separator: ", "))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        // Author
                        if let author = entry.createdBy {
                            HStack(spacing: 4) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9))
                                Text(author)
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        }
                        
                        // Last updated
                        Text(entry.fileUpdatedAt, style: .relative)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 1 : 0.5)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
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
