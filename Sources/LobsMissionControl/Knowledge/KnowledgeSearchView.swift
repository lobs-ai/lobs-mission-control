import SwiftUI

struct KnowledgeSearchView: View {
    @ObservedObject var service: KnowledgeService
    let onSelectEntry: (KnowledgeEntry) -> Void
    
    @State private var searchQuery = ""
    @State private var typeFilter: KnowledgeType? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    // Search input
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search knowledge...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14))
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                service.searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Type filter
                    Menu {
                        Button("All Types") {
                            typeFilter = nil
                            if !searchQuery.isEmpty {
                                performSearch()
                            }
                        }
                        
                        Divider()
                        
                        ForEach(KnowledgeType.allCases, id: \.self) { type in
                            Button {
                                typeFilter = type
                                if !searchQuery.isEmpty {
                                    performSearch()
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
                            Text(typeFilter?.displayName ?? "All Types")
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        performSearch()
                    } label: {
                        Text("Search")
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if !searchQuery.isEmpty {
                    HStack {
                        Text("\(service.searchResults.count) results")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Results
            if searchQuery.isEmpty {
                emptySearchState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if service.searchResults.isEmpty {
                            noResultsState
                        } else {
                            ForEach(service.searchResults) { entry in
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
        }
        .onChange(of: searchQuery) { oldValue, newValue in
            // Debounce search
            searchTask?.cancel()
            
            guard !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                service.searchResults = []
                return
            }
            
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if !Task.isCancelled {
                    await service.search(query: newValue, type: typeFilter)
                }
            }
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("Search Knowledge")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("Enter keywords to search across titles and content")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)
            Text("No results found")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("Try different keywords or remove filters")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        Task {
            await service.search(query: searchQuery, type: typeFilter)
        }
    }
}
