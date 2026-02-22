import SwiftUI

private typealias ATheme = Theme

/// Usage analytics view showing model/provider usage from the /api/usage/dashboard endpoint
struct UsageView: View {
  let apiService: APIService
  @Binding var isPresented: Bool
  
  @State private var selectedWindow: String = "month"
  @State private var dashboardData: UsageDashboardResponse?
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?
  
  let windows = ["day", "week", "month"]
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        // Header with window picker
        HStack(spacing: 12) {
          Image(systemName: "chart.pie.fill")
            .font(.title)
            .foregroundStyle(.linearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("Usage Analytics")
            .font(.title)
            .fontWeight(.bold)
          
          Spacer()
          
          Picker("Period", selection: $selectedWindow) {
            Text("Day").tag("day")
            Text("Week").tag("week")
            Text("Month").tag("month")
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 240)
        }
        
        if isLoading {
          ProgressView("Loading usage data...")
            .padding(.vertical, 40)
        } else if let error = errorMessage {
          ErrorBanner(message: error) {
            errorMessage = nil
          }
        } else if let data = dashboardData {
          UsageContent(data: data)
        } else {
          Text("No usage data available")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, 40)
        }
      }
      .padding(32)
    }
    .background(ATheme.boardBg)
    .task {
      await loadData()
    }
    .onChange(of: selectedWindow) { _ in
      Task {
        await loadData()
      }
    }
  }
  
  private func loadData() async {
    isLoading = true
    errorMessage = nil
    
    do {
      dashboardData = try await apiService.loadUsageDashboard(window: selectedWindow)
    } catch {
      errorMessage = "Failed to load usage data: \(error.localizedDescription)"
    }
    
    isLoading = false
  }
}

// MARK: - Usage Content

private struct UsageContent: View {
  let data: UsageDashboardResponse
  
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      // Summary cards
      HStack(spacing: 16) {
        SummaryCard(
          title: "Total Tasks",
          value: "\(data.totals.taskCount)",
          icon: "checkmark.circle.fill",
          color: .blue
        )
        SummaryCard(
          title: "Total Tokens",
          value: formatTokens(data.totals.totalTokens),
          icon: "cpu.fill",
          color: .purple
        )
        SummaryCard(
          title: "Total Cost",
          value: String(format: "$%.2f", data.totals.estimatedCostUsd),
          icon: "dollarsign.circle.fill",
          color: .green
        )
      }
      
      // Provider breakdown
      if !data.byProvider.isEmpty {
        ProviderBreakdownTable(providers: data.byProvider)
      }
      
      // Model breakdown
      if !data.byModel.isEmpty {
        ModelBreakdownTable(models: data.byModel)
      }
    }
  }
}

// MARK: - Summary Card

private struct SummaryCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 10) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 12))
          .foregroundStyle(color)
        Text(title)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      }
      Text(value)
        .font(.title2)
        .fontWeight(.bold)
        .foregroundStyle(color)
    }
    .frame(minWidth: 130, maxWidth: .infinity)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .background(ATheme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: ATheme.cardRadius))
    .overlay(
      RoundedRectangle(cornerRadius: ATheme.cardRadius)
        .stroke(ATheme.border, lineWidth: 0.5)
    )
  }
}

// MARK: - Provider Breakdown Table

private struct ProviderBreakdownTable: View {
  let providers: [UsageByProvider]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("By Provider")
        .font(.headline)
        .fontWeight(.bold)
      
      VStack(spacing: 0) {
        // Header
        HStack(spacing: 12) {
          Text("Provider")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 100, alignment: .leading)
          Text("Tasks")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 60, alignment: .trailing)
          Text("Tokens")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .trailing)
          Text("Cost")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 80, alignment: .trailing)
          Text("Errors")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
        
        Divider()
        
        // Rows
        ForEach(providers) { provider in
          VStack(spacing: 0) {
            HStack(spacing: 12) {
              Text(provider.provider.capitalized)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 100, alignment: .leading)
              Text("\(provider.taskCount)")
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 60, alignment: .trailing)
              Text(formatTokens(provider.totalTokens))
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 90, alignment: .trailing)
              Text(String(format: "$%.2f", provider.estimatedCostUsd))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.green)
                .frame(width: 80, alignment: .trailing)
              Text("\(provider.errorCount)")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(provider.errorCount > 0 ? .red : .secondary)
                .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if provider.id != providers.last?.id {
              Divider()
            }
          }
        }
      }
      .background(ATheme.cardBg)
      .clipShape(RoundedRectangle(cornerRadius: ATheme.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: ATheme.cardRadius)
          .stroke(ATheme.border, lineWidth: 0.5)
      )
    }
  }
}

// MARK: - Model Breakdown Table

private struct ModelBreakdownTable: View {
  let models: [UsageByModel]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("By Model")
        .font(.headline)
        .fontWeight(.bold)
      
      VStack(spacing: 0) {
        // Header
        HStack(spacing: 12) {
          Text("Model")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 180, alignment: .leading)
          Text("Tasks")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 60, alignment: .trailing)
          Text("Tokens")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 90, alignment: .trailing)
          Text("Cost")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
        
        Divider()
        
        // Rows
        ForEach(models) { model in
          VStack(spacing: 0) {
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 2) {
                Text(model.model)
                  .font(.system(size: 13, weight: .medium))
                  .lineLimit(1)
                Text(model.provider)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
              }
              .frame(width: 180, alignment: .leading)
              
              Text("\(model.taskCount)")
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 60, alignment: .trailing)
              Text(formatTokens(model.totalTokens))
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 90, alignment: .trailing)
              Text(String(format: "$%.2f", model.estimatedCostUsd))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.green)
                .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            if model.id != models.last?.id {
              Divider()
            }
          }
        }
      }
      .background(ATheme.cardBg)
      .clipShape(RoundedRectangle(cornerRadius: ATheme.cardRadius))
      .overlay(
        RoundedRectangle(cornerRadius: ATheme.cardRadius)
          .stroke(ATheme.border, lineWidth: 0.5)
      )
    }
  }
}

// MARK: - Error Banner

private struct ErrorBanner: View {
  let message: String
  let onDismiss: () -> Void
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
      Spacer()
      Button("Dismiss", action: onDismiss)
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
    }
    .padding(16)
    .background(Color.red.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.red.opacity(0.3), lineWidth: 1)
    )
  }
}

// MARK: - Formatters

private func formatTokens(_ count: Int) -> String {
  if count >= 1_000_000 {
    return String(format: "%.1fM", Double(count) / 1_000_000)
  } else if count >= 1_000 {
    return String(format: "%.1fK", Double(count) / 1_000)
  }
  return "\(count)"
}
