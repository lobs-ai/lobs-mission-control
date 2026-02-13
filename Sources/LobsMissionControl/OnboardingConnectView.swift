import SwiftUI

/// Onboarding step for connecting to the lobs-server.
///
/// This is the critical setup step where the user:
/// 1. Enters their server URL (e.g., http://localhost:8000 or Tailscale IP)
/// 2. Enters their API token
/// 3. Tests the connection (health check + authenticated status call)
/// 4. Can only proceed if connection succeeds
struct OnboardingConnectView: View {
  @EnvironmentObject var wizard: OnboardingWizardContext
  
  @State private var serverURL: String = "http://localhost:8000"
  @State private var apiToken: String = ""
  
  @State private var isTestingConnection: Bool = false
  @State private var connectionStatus: ConnectionStatus?
  
  enum ConnectionStatus {
    case success(message: String)
    case failure(message: String)
    
    var isSuccess: Bool {
      if case .success = self { return true }
      return false
    }
  }
  
  let onComplete: (String, String) -> Void
  
  var body: some View {
    VStack(spacing: 28) {
      Spacer()
      
      VStack(spacing: 16) {
        Image(systemName: "server.rack")
          .font(.system(size: 40))
          .foregroundColor(Theme.accent)
        
        Text("Connect to Server")
          .font(.system(size: 28, weight: .semibold))
        
        Text("Enter your lobs-server URL and API token to get started.")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 480)
      }
      
      VStack(alignment: .leading, spacing: 16) {
        // Server URL field
        VStack(alignment: .leading, spacing: 6) {
          Text("Server URL")
            .font(.system(size: 13, weight: .medium))
          
          TextField("http://localhost:8000", text: $serverURL)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.cardBg)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            .onChange(of: serverURL) { _ in
              connectionStatus = nil  // Clear status when URL changes
              updateWizardState()
            }
          
          Text("Example: http://100.64.0.1:8000 (Tailscale) or http://localhost:8000")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        
        // API Token field
        VStack(alignment: .leading, spacing: 6) {
          Text("API Token")
            .font(.system(size: 13, weight: .medium))
          
          SecureField("Enter your API token", text: $apiToken)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.cardBg)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
            .onChange(of: apiToken) { _ in
              connectionStatus = nil  // Clear status when token changes
              updateWizardState()
            }
          
          Text("Get this from your server admin or generate with bin/generate_token.py")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        
        // Test Connection button
        Button(action: { Task { await testConnection() } }) {
          HStack(spacing: 6) {
            if isTestingConnection {
              ProgressView()
                .scaleEffect(0.7)
                .frame(width: 14, height: 14)
            } else {
              Image(systemName: "network")
                .font(.system(size: 13))
            }
            Text(isTestingConnection ? "Testing..." : "Test Connection")
              .font(.system(size: 13, weight: .medium))
          }
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(canTestConnection ? Theme.accent : Theme.accent.opacity(0.5))
        .cornerRadius(8)
        .disabled(!canTestConnection || isTestingConnection)
        
        // Connection status feedback
        if let status = connectionStatus {
          HStack(spacing: 8) {
            Image(systemName: status.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundColor(status.isSuccess ? .green : .red)
              .font(.system(size: 14))
            
            switch status {
            case .success(let message):
              Text(message)
                .font(.system(size: 12))
                .foregroundColor(.green)
            case .failure(let message):
              Text(message)
                .font(.system(size: 12))
                .foregroundColor(.red)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(status.isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
          .cornerRadius(8)
        }
      }
      .frame(width: 480)
      .padding(20)
      .background(Theme.cardBg)
      .cornerRadius(12)
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
      
      Spacer()
      
      Text("Connection must succeed before continuing")
        .font(.system(size: 13))
        .foregroundColor(.secondary)
        .padding(.bottom, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
    .onAppear {
      updateWizardState()
    }
  }
  
  // MARK: - Connection Testing
  
  private var canTestConnection: Bool {
    !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  private var canProceed: Bool {
    connectionStatus?.isSuccess ?? false
  }
  
  private func updateWizardState() {
    wizard.configureNext(title: "Next", enabled: canProceed) {
      onComplete(serverURL, apiToken)
    }
  }
  
  private func testConnection() async {
    guard canTestConnection else { return }
    
    isTestingConnection = true
    connectionStatus = nil
    
    let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedToken = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
    
    let (success, message) = await performConnectionTest(serverURL: trimmedURL, apiToken: trimmedToken)
    
    isTestingConnection = false
    connectionStatus = success ? .success(message: message) : .failure(message: message)
    updateWizardState()
  }
  
  /// Test connection to the server:
  /// 1. Try GET /api/health (no auth) to verify server is reachable
  /// 2. Try GET /api/status/overview (requires auth) to verify token is valid
  private func performConnectionTest(serverURL: String, apiToken: String) async -> (Bool, String) {
    // Step 1: Health check (no auth needed)
    guard let healthURL = URL(string: "\(serverURL)/api/health") else {
      return (false, "Invalid server URL format")
    }
    
    var healthRequest = URLRequest(url: healthURL)
    healthRequest.httpMethod = "GET"
    healthRequest.timeoutInterval = 10
    
    do {
      let (healthData, healthResponse) = try await URLSession.shared.data(for: healthRequest)
      
      guard let httpResponse = healthResponse as? HTTPURLResponse else {
        return (false, "Invalid server response")
      }
      
      guard httpResponse.statusCode == 200 else {
        return (false, "Server health check failed (HTTP \(httpResponse.statusCode))")
      }
      
      // Verify we got a valid JSON response
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      
      guard let healthStatus = try? decoder.decode(HealthResponse.self, from: healthData) else {
        return (false, "Server returned invalid health data")
      }
      
      guard healthStatus.status == "healthy" else {
        return (false, "Server reports unhealthy status: \(healthStatus.status)")
      }
      
    } catch {
      return (false, "Could not reach server: \(error.localizedDescription)")
    }
    
    // Step 2: Authenticated endpoint test (verify token works)
    guard let statusURL = URL(string: "\(serverURL)/api/status/overview") else {
      return (false, "Invalid server URL format")
    }
    
    var statusRequest = URLRequest(url: statusURL)
    statusRequest.httpMethod = "GET"
    statusRequest.timeoutInterval = 10
    statusRequest.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
    
    do {
      let (_, statusResponse) = try await URLSession.shared.data(for: statusRequest)
      
      guard let httpResponse = statusResponse as? HTTPURLResponse else {
        return (false, "Invalid authentication response")
      }
      
      if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
        return (false, "Invalid API token (authentication failed)")
      }
      
      guard httpResponse.statusCode == 200 else {
        return (false, "Server error during authentication (HTTP \(httpResponse.statusCode))")
      }
      
      return (true, "✓ Connected successfully!")
      
    } catch {
      return (false, "Authentication test failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - Response Models

private struct HealthResponse: Codable {
  let status: String
  let version: String?
}

// // #Preview {
// OnboardingConnectView(onComplete: { url, token in
//   print("Connected to \(url) with token \(token)")
// })
// .environmentObject(OnboardingWizardContext())
// .frame(width: 800, height: 600)
// }
