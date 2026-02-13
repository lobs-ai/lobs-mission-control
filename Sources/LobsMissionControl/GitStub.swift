import Foundation

// MARK: - Git Stub (temporary until Git implementation is restored)

struct GitOperationResult {
  let success: Bool
  let output: String
  let stderr: String
  let exitCode: Int32
  var error: Error?
  
  // Aliases for compatibility
  var ok: Bool { success }
  var stdout: String { output }
  var suggestsPull: Bool { false }
  var canRetry: Bool { false }
  
  static func success(output: String = "") -> GitOperationResult {
    GitOperationResult(success: true, output: output, stderr: "", exitCode: 0, error: nil)
  }
  
  static func failure(output: String = "", stderr: String = "", error: Error? = nil) -> GitOperationResult {
    GitOperationResult(success: false, output: output, stderr: stderr, exitCode: 1, error: error)
  }
}

typealias GitResult = Result<GitOperationResult, Error>

extension Result where Success == GitOperationResult, Failure == Error {
  var ok: Bool {
    if case .success(let result) = self {
      return result.success
    }
    return false
  }
  
  var stderr: String {
    if case .success(let result) = self {
      return result.stderr
    }
    return ""
  }
}

struct Git {
  typealias Result = Swift.Result<GitOperationResult, Error>
  
  static func runWithErrorHandling(_ args: [String], cwd: URL? = nil) -> GitOperationResult {
    // Stub: return empty result
    return .success(output: "")
  }
  
  static func runAsync(_ args: [String], cwd: URL? = nil) async throws -> GitOperationResult {
    // Stub: return empty result
    return .success(output: "")
  }
  
  static func runAsyncWithErrorHandling(_ args: [String], cwd: URL? = nil) async -> GitOperationResult {
    // Stub: return empty result
    return .success(output: "")
  }
  
  static func runWithRetry(_ args: [String], cwd: URL? = nil, maxRetries: Int = 3, initialDelay: Double = 1.0) async -> GitOperationResult {
    // Stub: return empty result
    return .success(output: "")
  }
}
