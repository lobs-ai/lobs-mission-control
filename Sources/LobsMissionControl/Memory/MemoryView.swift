import SwiftUI

struct MemoryView: View {
    @StateObject var viewModel: MemoryViewModel
    @State private var showQuickCapture = true
    @State private var selectedTab: FilterTab = .all
    
    enum FilterTab: String, CaseIterable {
        case all = "All"
        case longTerm = "Long-term"
        case daily = "Daily"
        case custom = "Custom"
        
        var filterValue: String? {
            switch self {
            case .all: return nil
            case .longTerm: return "long_term"
            case .daily: return "daily"
            case .custom: return "custom"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left column: Memory list
            VStack(spacing: 0) {
                // Filter tabs
                HStack(spacing: 4) {
                    ForEach(FilterTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                            viewModel.filterType = tab.filterValue
                            Task {
                                await viewModel.loadMemories()
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                                .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Divider()
                
                // Memory list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredMemories) { item in
                            MemoryListItem(
                                item: item,
                                isSelected: viewModel.selectedMemory?.id == item.id
                            ) {
                                Task {
                                    await viewModel.selectMemory(item)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 280)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Center column: Memory content
            if let memory = viewModel.selectedMemory {
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if viewModel.isEditing {
                                TextField("Title", text: $viewModel.editTitle)
                                    .textFieldStyle(.plain)
                                    .font(.title2.weight(.bold))
                            } else {
                                Text(memory.displayTitle)
                                    .font(.title2.weight(.bold))
                                Spacer()
                                Button {
                                    viewModel.startEditing()
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.body)
                                }
                                .buttonStyle(.plain)
                                .help("Edit memory")
                            }
                        }
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: memory.typeBadgeIcon)
                                    .font(.caption)
                                    .foregroundStyle(Color(nsColor: memory.typeBadgeColor))
                                Text(memory.memoryType.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let date = memory.date {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.caption)
                                    Text(date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text("Updated \(memory.updatedAt, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .windowBackgroundColor))
                    
                    Divider()
                    
                    // Content
                    if viewModel.isEditing {
                        VStack(spacing: 12) {
                            TextEditor(text: $viewModel.editContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            HStack {
                                Spacer()
                                Button("Cancel") {
                                    viewModel.cancelEdit()
                                }
                                .buttonStyle(.plain)
                                
                                Button("Save") {
                                    Task {
                                        await viewModel.saveEdit()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    } else {
                        ScrollView {
                            Text(memory.content)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Select a memory to view")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Right column: Quick capture (toggleable)
            if showQuickCapture {
                Divider()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Quick Capture")
                            .font(.headline)
                        Spacer()
                        Button {
                            showQuickCapture = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    
                    Divider()
                    
                    VStack(spacing: 12) {
                        TextEditor(text: $viewModel.captureText)
                            .font(.body)
                            .frame(height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                        
                        Button {
                            Task {
                                await viewModel.capture()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                Text("Capture to Today")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Text("Appends to today's daily memory")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    
                    Spacer()
                    
                    // Show today's memory preview
                    if let todaysMemory = viewModel.filteredMemories.first(where: {
                        $0.memoryType == "daily" && $0.date.map { Calendar.current.isDateInToday($0) } ?? false
                    }) {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's Memory")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            
                            Button {
                                Task {
                                    await viewModel.selectMemory(todaysMemory)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.blue)
                                    Text(todaysMemory.title)
                                        .font(.caption)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                    }
                }
                .frame(width: 280)
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                // Toggle button to show quick capture again
                Button {
                    showQuickCapture = true
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .help("Show quick capture")
            }
        }
        .task {
            await viewModel.loadMemories()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

// MARK: - Memory List Item

private struct MemoryListItem: View {
    let item: MemoryItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if item.memoryType == "long_term" {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                    Text(item.title)
                        .font(.system(size: 13, weight: item.memoryType == "long_term" ? .semibold : .regular))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                HStack(spacing: 8) {
                    if let date = item.date {
                        Text(date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color(nsColor: item.typeBadgeColor))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Extension

private extension MemoryDetail {
    var displayTitle: String {
        if memoryType == "long_term" {
            return title
        }
        return title
    }
    
    var typeBadgeIcon: String {
        switch memoryType {
        case "long_term": return "brain.head.profile"
        case "daily": return "calendar"
        case "custom": return "doc.text"
        default: return "doc"
        }
    }
    
    var typeBadgeColor: NSColor {
        switch memoryType {
        case "long_term": return .systemPurple
        case "daily": return .systemBlue
        case "custom": return .systemGreen
        default: return .systemGray
        }
    }
}
