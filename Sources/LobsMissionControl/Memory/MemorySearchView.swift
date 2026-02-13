import SwiftUI

struct MemorySearchView: View {
    @ObservedObject var viewModel: MemoryViewModel
    @FocusState private var isSearchFocused: Bool
    let onSelectResult: (MemorySearchResult) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search memories...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        Task {
                            await viewModel.search()
                        }
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Results
            if viewModel.searchResults.isEmpty {
                if viewModel.searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("Search your memories")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Type a query and press Enter")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No results found")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.searchResults) { result in
                            SearchResultRow(result: result) {
                                onSelectResult(result)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: MemorySearchResult
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(result.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let date = result.date {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // Snippet with context
                Text(result.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 8) {
                    // Type badge
                    HStack(spacing: 3) {
                        Image(systemName: typeIcon(result.memoryType))
                            .font(.system(size: 10))
                        Text(result.memoryType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Color(nsColor: typeColor(result.memoryType)))
                    
                    Spacer()
                    
                    // Relevance score
                    if let score = result.score {
                        Text(String(format: "%.0f%%", score * 100))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
        .overlay(
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private func typeIcon(_ type: String) -> String {
        switch type {
        case "long_term": return "brain.head.profile"
        case "daily": return "calendar"
        case "custom": return "doc.text"
        default: return "doc"
        }
    }
    
    private func typeColor(_ type: String) -> NSColor {
        switch type {
        case "long_term": return .systemPurple
        case "daily": return .systemBlue
        case "custom": return .systemGreen
        default: return .systemGray
        }
    }
}
