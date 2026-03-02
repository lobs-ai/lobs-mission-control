import Foundation
import os

private let ksLog = Logger(subsystem: "com.lobs.missioncontrol", category: "Knowledge")

@MainActor
class KnowledgeService: ObservableObject {
    private let apiService: APIService
    
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
            var urlString = "\(apiService.baseURL)/api/knowledge/feed?limit=\(limit)"
            if let since = since {
                let isoFormatter = ISO8601DateFormatter()
                urlString += "&since=\(isoFormatter.string(from: since))"
            }
            
            guard let url = URL(string: urlString) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            if let token = apiService.apiToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.parseErrorResponse(data, statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let feedResponse = try decoder.decode(KnowledgeFeedResponse.self, from: data)
            ksLog.info("✅ Feed loaded: \(feedResponse.entries.count) entries")
            feedEntries = feedResponse.entries
            isLoading = false
        } catch {
            ksLog.error("❌ Knowledge feed error: \(error)")
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
            var urlString = "\(apiService.baseURL)/api/knowledge"
            var queryParams: [String] = []
            
            if let path = path {
                queryParams.append("path=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }
            
            if let type = type {
                queryParams.append("type=\(type.rawValue)")
            }
            
            if let tags = tags, !tags.isEmpty {
                let tagsParam = tags.joined(separator: ",")
                queryParams.append("tags=\(tagsParam.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            }
            
            if !queryParams.isEmpty {
                urlString += "?" + queryParams.joined(separator: "&")
            }
            
            guard let url = URL(string: urlString) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            if let token = apiService.apiToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.parseErrorResponse(data, statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let browseResponse = try decoder.decode(KnowledgeBrowseResponse.self, from: data)
            browseEntries = browseResponse.entries
            isLoading = false
        } catch {
            ksLog.error("❌ Knowledge error: \(error)")
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
            var urlString = "\(apiService.baseURL)/api/knowledge?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=\(limit)"
            
            if let type = type {
                urlString += "&type=\(type.rawValue)"
            }
            
            guard let url = URL(string: urlString) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            if let token = apiService.apiToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.parseErrorResponse(data, statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            
            let browseResponse = try decoder.decode(KnowledgeBrowseResponse.self, from: data)
            searchResults = browseResponse.entries
            isLoading = false
        } catch {
            ksLog.error("❌ Knowledge error: \(error)")
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Content
    
    func loadContent(path: String) async throws -> String {
        let urlString = "\(apiService.baseURL)/api/knowledge/content?path=\(path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        if let token = apiService.apiToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.parseErrorResponse(data, statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let contentResponse = try decoder.decode(KnowledgeContentResponse.self, from: data)
        return contentResponse.content
    }
    
    // MARK: - Sync
    
    func triggerSync() async {
        do {
            let urlString = "\(apiService.baseURL)/api/knowledge/sync"
            
            guard let url = URL(string: urlString) else {
                throw APIError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            if let token = apiService.apiToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.parseErrorResponse(data, statusCode: httpResponse.statusCode)
            }
            
            // Success - no need to handle response
        } catch {
            ksLog.error("❌ Knowledge sync error: \(error)")
            self.error = error.localizedDescription
        }
    }
}
