import Foundation

/// Generic async loader with stale-while-revalidate semantics,
/// retry with exponential backoff, and deduplication of in-flight requests.
///
/// Usage:
/// ```swift
/// let loader = SurfaceLoader<[InboxItem]>(
///     ttl: 30,
///     fetch: { try await api.loadInboxItems() }
/// )
/// // Returns cached data immediately if available, refreshes in background if stale.
/// let items = await loader.load()
/// ```
@MainActor
final class SurfaceLoader<T: Sendable> {
    typealias FetchBlock = @Sendable () async throws -> T

    // MARK: - Configuration

    /// How long cached data is considered fresh (seconds).
    let ttl: TimeInterval
    /// Maximum number of retry attempts on transient failure.
    let maxRetries: Int
    /// Base delay between retries (doubles each attempt).
    let baseRetryDelay: TimeInterval
    /// Human-readable label for logging.
    let label: String

    // MARK: - State

    /// Last successfully fetched value.
    private(set) var value: T?
    /// Timestamp of last successful fetch.
    private(set) var lastFetchedAt: Date?
    /// Whether a fetch is currently in-flight.
    private(set) var isLoading: Bool = false
    /// Last error from a failed fetch (cleared on success).
    private(set) var lastError: Error?

    private let fetch: FetchBlock
    private var inFlightTask: Task<T, Error>?

    // MARK: - Init

    init(
        label: String = "surface",
        ttl: TimeInterval = 30,
        maxRetries: Int = 2,
        baseRetryDelay: TimeInterval = 1.0,
        fetch: @escaping FetchBlock
    ) {
        self.label = label
        self.ttl = ttl
        self.maxRetries = maxRetries
        self.baseRetryDelay = baseRetryDelay
        self.fetch = fetch
    }

    // MARK: - Public API

    /// Whether the cached value is stale or missing.
    var isStale: Bool {
        guard let lastFetchedAt else { return true }
        return Date().timeIntervalSince(lastFetchedAt) > ttl
    }

    /// Returns cached data immediately if fresh. If stale, returns cached data
    /// (if available) while triggering a background refresh. If no cached data,
    /// waits for the fetch to complete.
    @discardableResult
    func load() async -> T? {
        // Fresh cache — return immediately
        if !isStale, let value {
            return value
        }

        // Stale but have cached data — return it and refresh in background
        if let value {
            triggerBackgroundRefresh()
            return value
        }

        // No cached data — must wait for fetch
        return try? await fetchWithRetry()
    }

    /// Force a fresh fetch, ignoring cache. Waits for result.
    @discardableResult
    func forceRefresh() async -> T? {
        return try? await fetchWithRetry()
    }

    /// Trigger a background refresh without blocking the caller.
    /// No-op if a fetch is already in-flight.
    func triggerBackgroundRefresh() {
        guard inFlightTask == nil else { return }
        inFlightTask = Task {
            defer { inFlightTask = nil }
            return try await fetchWithRetryInternal()
        }
    }

    /// Invalidate cached data (next load will fetch fresh).
    func invalidate() {
        lastFetchedAt = nil
    }

    // MARK: - Internal

    private func fetchWithRetry() async throws -> T {
        // Deduplicate: if there's already a fetch in-flight, await it.
        if let existing = inFlightTask {
            return try await existing.value
        }

        let task = Task {
            try await fetchWithRetryInternal()
        }
        inFlightTask = task

        defer { inFlightTask = nil }
        return try await task.value
    }

    private func fetchWithRetryInternal() async throws -> T {
        isLoading = true
        defer { isLoading = false }

        var lastErr: Error?
        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            do {
                let result = try await fetch()
                // Success — update cache
                await MainActor.run {
                    self.value = result
                    self.lastFetchedAt = Date()
                    self.lastError = nil
                }
                return result
            } catch {
                lastErr = error
                // Only retry on transient errors (timeout, connection)
                if !isTransient(error) { break }
                print("⚠️ [\(label)] Attempt \(attempt + 1)/\(maxRetries + 1) failed: \(error.localizedDescription)")
            }
        }
        let finalErr = lastErr ?? APIError.networkError(NSError(domain: "SurfaceLoader", code: -1))
        await MainActor.run {
            self.lastError = finalErr
        }
        throw finalErr
    }

    private func isTransient(_ error: Error) -> Bool {
        if let apiErr = error as? APIError {
            switch apiErr {
            case .timeout, .connectionError, .networkError:
                return true
            default:
                return false
            }
        }
        if let urlErr = error as? URLError {
            return [.timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost].contains(urlErr.code)
        }
        return false
    }
}
