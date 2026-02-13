import Foundation
import SwiftUI

@MainActor
class StatusViewModel: ObservableObject {
  @Published var overview: SystemOverview?
  @Published var activity: [ActivityEvent] = []
  @Published var costs: CostSummary?
  
  @Published var isLoading = false
  @Published var error: String?
  @Published var lastRefresh: Date?
  
  private let apiService: APIService
  private var refreshTimer: Timer?
  
  init(apiService: APIService) {
    self.apiService = apiService
  }
  
  func startAutoRefresh() {
    // Initial load
    Task { await loadAll() }
    
    // Refresh every 30 seconds
    refreshTimer?.invalidate()
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.loadAll(silent: true)
      }
    }
  }
  
  func stopAutoRefresh() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }
  
  func loadAll(silent: Bool = false) async {
    if !silent {
      isLoading = true
      error = nil
    }
    
    async let overviewTask = loadOverview(silent: silent)
    async let activityTask = loadActivity(silent: silent)
    async let costsTask = loadCosts(silent: silent)
    
    await overviewTask
    await activityTask
    await costsTask
    
    if !silent {
      isLoading = false
      lastRefresh = Date()
    }
  }
  
  private func loadOverview(silent: Bool = false) async {
    do {
      overview = try await apiService.fetchSystemOverview()
    } catch {
      if !silent {
        self.error = "Failed to load system overview: \(error.localizedDescription)"
      }
    }
  }
  
  private func loadActivity(silent: Bool = false) async {
    do {
      activity = try await apiService.fetchActivity(limit: 50, since: nil)
    } catch {
      if !silent {
        self.error = "Failed to load activity: \(error.localizedDescription)"
      }
    }
  }
  
  private func loadCosts(silent: Bool = false) async {
    do {
      costs = try await apiService.fetchCosts()
    } catch {
      if !silent {
        // Cost tracking might not be enabled, so don't show error
      }
    }
  }
  
  func pauseOrchestrator() async {
    do {
      try await apiService.pauseOrchestrator()
      await loadOverview()
    } catch {
      self.error = "Failed to pause orchestrator: \(error.localizedDescription)"
    }
  }
  
  func resumeOrchestrator() async {
    do {
      try await apiService.resumeOrchestrator()
      await loadOverview()
    } catch {
      self.error = "Failed to resume orchestrator: \(error.localizedDescription)"
    }
  }
  
  deinit {
    refreshTimer?.invalidate()
  }
}
