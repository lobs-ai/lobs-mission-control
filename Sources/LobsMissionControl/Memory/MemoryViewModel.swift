import Foundation
import SwiftUI

@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var memories: [MemoryItem] = []
    @Published var selectedMemory: MemoryDetail? = nil
    @Published var searchResults: [MemorySearchResult] = []
    @Published var searchQuery: String = ""
    @Published var isEditing: Bool = false
    @Published var editContent: String = ""
    @Published var editTitle: String = ""
    @Published var filterType: String? = nil
    @Published var captureText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
    private let apiService: APIService
    
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Load Memories
    
    func loadMemories() async {
        isLoading = true
        error = nil
        
        do {
            memories = try await apiService.fetchMemories(type: filterType)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Select Memory
    
    func selectMemory(_ item: MemoryItem) async {
        isLoading = true
        error = nil
        
        do {
            selectedMemory = try await apiService.fetchMemory(id: item.id)
            editContent = selectedMemory?.content ?? ""
            editTitle = selectedMemory?.title ?? ""
            isEditing = false
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Search
    
    func search() async {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            searchResults = try await apiService.searchMemories(query: searchQuery)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Edit
    
    func startEditing() {
        guard let memory = selectedMemory else { return }
        editContent = memory.content
        editTitle = memory.title
        isEditing = true
    }
    
    func cancelEdit() {
        guard let memory = selectedMemory else { return }
        editContent = memory.content
        editTitle = memory.title
        isEditing = false
    }
    
    func saveEdit() async {
        guard let memory = selectedMemory else { return }
        
        isLoading = true
        error = nil
        
        do {
            let updated = try await apiService.updateMemory(
                id: memory.id,
                content: editContent,
                title: editTitle != memory.title ? editTitle : nil
            )
            selectedMemory = updated
            isEditing = false
            isLoading = false
            
            // Reload the list to reflect changes
            await loadMemories()
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Capture
    
    func capture() async {
        guard !captureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            _ = try await apiService.captureMemory(content: captureText)
            captureText = ""
            isLoading = false
            
            // Reload to show the updated daily memory
            await loadMemories()
            
            // If today's memory is visible, reload it
            if let current = selectedMemory,
               current.memoryType == "daily",
               let date = current.date,
               Calendar.current.isDateInToday(date) {
                await selectMemory(memories.first(where: { $0.id == current.id })!)
            }
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Create Memory
    
    func createMemory(title: String, content: String, type: String, date: Date?) async {
        isLoading = true
        error = nil
        
        do {
            let created = try await apiService.createMemory(
                title: title,
                content: content,
                type: type,
                date: date
            )
            
            // Reload the list
            await loadMemories()
            
            // Select the new memory
            if let item = memories.first(where: { $0.id == created.id }) {
                await selectMemory(item)
            }
            
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Filtered Memories
    
    var filteredMemories: [MemoryItem] {
        let filtered = filterType != nil
            ? memories.filter { $0.memoryType == filterType }
            : memories
        
        // Sort: long-term pinned at top, then by date descending
        return filtered.sorted { lhs, rhs in
            if lhs.memoryType == "long_term" && rhs.memoryType != "long_term" {
                return true
            }
            if lhs.memoryType != "long_term" && rhs.memoryType == "long_term" {
                return false
            }
            
            // For daily memories, sort by date descending
            if let lDate = lhs.date, let rDate = rhs.date {
                return lDate > rDate
            }
            
            // Fall back to updated_at
            return lhs.updatedAt > rhs.updatedAt
        }
    }
    
    // MARK: - Grouped Memories (for timeline view)
    
    func groupedByMonth() -> [(month: String, items: [MemoryItem])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        let grouped = Dictionary(grouping: filteredMemories.filter { $0.date != nil }) { item -> String in
            dateFormatter.string(from: item.date!)
        }
        
        return grouped.sorted { $0.key > $1.key }.map { (month: $0.key, items: $0.value.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }) }
    }
}
