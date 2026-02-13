import SwiftUI

struct MemoryTimelineView: View {
    @ObservedObject var viewModel: MemoryViewModel
    let onSelectMemory: (MemoryItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(viewModel.groupedByMonth(), id: \.month) { group in
                    VStack(alignment: .leading, spacing: 16) {
                        // Month header
                        HStack {
                            Text(group.month)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                            
                            Text("\(group.items.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Timeline entries
                        ForEach(group.items) { item in
                            TimelineEntry(item: item) {
                                onSelectMemory(item)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Timeline Entry

private struct TimelineEntry: View {
    let item: MemoryItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                // Date on left
                VStack(alignment: .trailing, spacing: 2) {
                    if let date = item.date {
                        Text(date, format: .dateTime.day())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 50)
                
                // Timeline dot and line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color(nsColor: typeBadgeColor(item.memoryType)))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 3)
                        )
                    
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(height: 120)
                
                // Memory card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if item.memoryType == "long_term" {
                            Image(systemName: "brain.head.profile")
                                .font(.body)
                                .foregroundStyle(.purple)
                        }
                        
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Image(systemName: typeIcon(item.memoryType))
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: typeBadgeColor(item.memoryType)))
                    }
                    
                    Text(item.memoryType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    HStack {
                        Spacer()
                        Text("Updated \(item.updatedAt, style: .relative)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 100)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func typeIcon(_ type: String) -> String {
        switch type {
        case "long_term": return "brain.head.profile"
        case "daily": return "calendar"
        case "custom": return "doc.text"
        default: return "doc"
        }
    }
    
    private func typeBadgeColor(_ type: String) -> NSColor {
        switch type {
        case "long_term": return .systemPurple
        case "daily": return .systemBlue
        case "custom": return .systemGreen
        default: return .systemGray
        }
    }
}
