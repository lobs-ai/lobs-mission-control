import Foundation
import os

private let ksLog = Logger(subsystem: "com.lobs.missioncontrol", category: "Knowledge")

@MainActor
class KnowledgeService: ObservableObject {
    let apiService: APIService
    
    @Published var feedEntries: [KnowledgeEntry] = []
    @Published var browseEntries: [KnowledgeEntry] = []
    @Published var searchResults: [KnowledgeEntry] = []
    @Published var currentPath: String? = nil
    @Published var isLoading = false
    @Published var error: String?
    
    init(apiService: APIService) {
        self.apiService = apiService
    }
    
    // MARK: - Feed
    
    func loadFeed(limit: Int = 20, since: Date? = nil) async {
        isLoading = true
        error = nil
        
        do {
            var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
            if let since = since {
                queryItems.append(URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since)))
            }
            
            let response: KnowledgeFeedResponse = try await apiService.request(
                method: "GET",
                path: "/api/knowledge/feed",
                queryItems: queryItems
            )
            feedEntries = response.entries
            isLoading = false
        } catch {
            print("[Knowledge] ❌ Feed error: \(error)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Browse
    
    func browse(path: String? = nil, type: KnowledgeType? = nil, tags: [String]? = nil) async {
        isLoading = true
        error = nil
        currentPath = path
        
        do {
            var queryItems: [URLQueryItem] = []
            if let path = path { queryItems.append(URLQueryItem(name: "path", value: path)) }
            if let type = type { queryItems.append(URLQueryItem(name: "type", value: type.rawValue)) }
            if let tags = tags, !tags.isEmpty { queryItems.append(URLQueryItem(name: "tags", value: tags.joined(separator: ","))) }
            
            let response: KnowledgeBrowseResponse = try await apiService.request(
                method: "GET",
                path: "/api/knowledge",
                queryItems: queryItems.isEmpty ? nil : queryItems
            )
            browseEntries = response.entries
            isLoading = false
        } catch {
            print("[Knowledge] ❌ Browse error: \(error)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Search
    
    func search(query: String, type: KnowledgeType? = nil, limit: Int = 50) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            var queryItems = [
                URLQueryItem(name: "search", value: query),
                URLQueryItem(name: "limit", value: String(limit))
            ]
            if let type = type { queryItems.append(URLQueryItem(name: "type", value: type.rawValue)) }
            
            let response: KnowledgeBrowseResponse = try await apiService.request(
                method: "GET",
                path: "/api/knowledge",
                queryItems: queryItems
            )
            searchResults = response.entries
            isLoading = false
        } catch {
            print("[Knowledge] ❌ Search error: \(error)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Content
    
    func loadContent(path: String) async throws -> String {
        let response: KnowledgeContentResponse = try await apiService.request(
            method: "GET",
            path: "/api/knowledge/content",
            queryItems: [URLQueryItem(name: "path", value: path)]
        )
        return response.content
    }
    
    // MARK: - Sync
    
    func triggerSync() async {
        do {
            try await apiService.requestVoid(method: "POST", path: "/api/knowledge/sync")
        } catch {
            print("[Knowledge] ❌ Sync error: \(error)")
            self.error = error.localizedDescription
        }
    }
}
