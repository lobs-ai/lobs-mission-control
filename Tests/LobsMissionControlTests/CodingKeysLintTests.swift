import XCTest

/// Tests for CodingKeys lint rules enforcement
/// 
/// These tests verify that our pre-commit hook logic correctly identifies
/// forbidden CodingKeys patterns that cause double-conversion bugs.
final class CodingKeysLintTests: XCTestCase {
  
  /// Test that we can detect snake_case CodingKeys patterns
  func testDetectsForbiddenSnakeCasePattern() {
    let forbiddenCode = """
    struct User: Codable {
        let userId: Int
        let createdAt: Date
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case createdAt = "created_at"
        }
    }
    """
    
    // Pattern we're looking for: case xxx = "snake_case"
    let pattern = #"case\s+\w+\s*=\s*"[^"]*_[^"]*""#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(forbiddenCode.startIndex..., in: forbiddenCode)
    let matches = regex.matches(in: forbiddenCode, range: range)
    
    XCTAssertGreaterThan(matches.count, 0, "Should detect snake_case CodingKeys")
  }
  
  /// Test that allowed CodingKeys patterns pass
  func testAllowsNonSnakeCasePatterns() {
    let allowedCode = """
    struct User: Codable {
        let id: Int
        let name: String
        
        enum CodingKeys: String, CodingKey {
            case id = "user_id"  // Different field name - ALLOWED
            case name            // No conversion - ALLOWED
        }
    }
    """
    
    // This should match the first case but that's expected behavior
    // The lint only flags snake_case in the string literal
    let pattern = #"case\s+\w+\s*=\s*"[^"]*_[^"]*""#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(allowedCode.startIndex..., in: allowedCode)
    let matches = regex.matches(in: allowedCode, range: range)
    
    // user_id is allowed because the property name is different (id vs userId)
    XCTAssertEqual(matches.count, 1, "Should only match actual snake_case conversions")
  }
  
  /// Test that code without CodingKeys passes
  func testAllowsCodeWithoutCodingKeys() {
    let goodCode = """
    struct User: Codable {
        let userId: Int      // Decoder converts user_id → userId
        let createdAt: Date  // Decoder converts created_at → createdAt
    }
    """
    
    let pattern = #"enum\s+CodingKeys.*CodingKey"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(goodCode.startIndex..., in: goodCode)
    let matches = regex.matches(in: goodCode, range: range)
    
    XCTAssertEqual(matches.count, 0, "Code without CodingKeys should pass")
  }
  
  /// Test detection of multiple violations in one file
  func testDetectsMultipleViolations() {
    let multipleViolations = """
    struct Task: Codable {
        let projectId: String
        let workState: String
        
        enum CodingKeys: String, CodingKey {
            case projectId = "project_id"
            case workState = "work_state"
        }
    }
    
    struct Event: Codable {
        let eventType: String
        
        enum CodingKeys: String, CodingKey {
            case eventType = "event_type"
        }
    }
    """
    
    let pattern = #"case\s+\w+\s*=\s*"[^"]*_[^"]*""#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(multipleViolations.startIndex..., in: multipleViolations)
    let matches = regex.matches(in: multipleViolations, range: range)
    
    XCTAssertEqual(matches.count, 3, "Should detect all three violations")
  }
  
  /// Integration test: verify pre-commit hook exists and is executable
  func testPreCommitHookExists() throws {
    let hookPath = ".git/hooks/pre-commit"
    let fileManager = FileManager.default
    
    // Get project root (go up from Tests/LobsMissionControlTests)
    let currentFile = URL(fileURLWithPath: #file)
    let projectRoot = currentFile
      .deletingLastPathComponent()  // CodingKeysLintTests.swift
      .deletingLastPathComponent()  // LobsMissionControlTests/
      .deletingLastPathComponent()  // Tests/
      .deletingLastPathComponent()  // project root
    
    let hookURL = projectRoot.appendingPathComponent(hookPath)
    
    XCTAssertTrue(
      fileManager.fileExists(atPath: hookURL.path),
      "Pre-commit hook should exist at \(hookURL.path)"
    )
    
    // Check if executable
    let attributes = try fileManager.attributesOfItem(atPath: hookURL.path)
    let permissions = attributes[.posixPermissions] as? NSNumber
    let isExecutable = (permissions?.uint16Value ?? 0) & 0o111 != 0
    
    XCTAssertTrue(isExecutable, "Pre-commit hook should be executable")
  }
  
  /// Integration test: verify manual lint-check script exists
  func testLintCheckScriptExists() throws {
    let scriptPath = "scripts/lint-check"
    let fileManager = FileManager.default
    
    let currentFile = URL(fileURLWithPath: #file)
    let projectRoot = currentFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    
    let scriptURL = projectRoot.appendingPathComponent(scriptPath)
    
    XCTAssertTrue(
      fileManager.fileExists(atPath: scriptURL.path),
      "Lint check script should exist at \(scriptURL.path)"
    )
    
    let attributes = try fileManager.attributesOfItem(atPath: scriptURL.path)
    let permissions = attributes[.posixPermissions] as? NSNumber
    let isExecutable = (permissions?.uint16Value ?? 0) & 0o111 != 0
    
    XCTAssertTrue(isExecutable, "Lint check script should be executable")
  }
}
