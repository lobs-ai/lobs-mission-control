# Integration Tests

End-to-end integration tests for critical Mission Control workflows.

## Overview

These tests verify complete workflows across server + client, ensuring that data flows correctly through:
1. API calls (REST or WebSocket)
2. AppViewModel state management
3. UI state updates

Unlike unit tests that test individual components, integration tests verify that the entire system works together correctly.

## Test Files

### 1. TaskLifecycleIntegrationTests.swift
**Workflow:** Task creation → status updates → completion

**Tests:**
- Create task via API → verify in UI state
- Update task status → verify state sync
- Complete task → verify completedAt timestamp
- Task counters update correctly
- Valid status transitions
- API error handling

**Key Scenarios:**
- Full lifecycle: not_started → in_progress → completed
- Task counter increments on creation
- State consistency across operations

### 2. ChatMessagingIntegrationTests.swift
**Workflow:** Send message → receive confirmation → sync with REST API

**Tests:**
- Send message via WebSocket → verify in UI
- Receive message from server → verify delivery
- Sync WebSocket messages with REST API history
- Message ordering by timestamp
- WebSocket reconnection
- Error handling (send failures, invalid messages)

**Key Scenarios:**
- Real-time message delivery
- Message deduplication between WebSocket and REST
- Message persistence across reconnections

### 3. MemoryCRUDIntegrationTests.swift
**Workflow:** Create → Read → Update → Delete memories

**Tests:**
- Create memory → verify in state
- Fetch all memories → verify sync
- Fetch single memory by ID
- Update memory content → verify state update
- Update only tags (partial update)
- Delete memory → verify removal
- Search memories by query and tags
- Full CRUD cycle
- API error handling

**Key Scenarios:**
- Markdown content preservation
- Partial updates (tags only)
- Search functionality
- State consistency throughout CRUD operations

## Architecture Pattern

### Mock-Based Testing
All integration tests use mock services instead of live API connections. This provides:
- **Fast execution** — no network latency
- **Deterministic results** — no flaky tests from network issues
- **Isolated testing** — no dependency on server being online
- **Controlled scenarios** — can test error cases easily

### Mock Services Structure

```swift
// 1. Define mock service
class MockAPIService {
  var shouldFail = false
  var mockError: Error?
  var mockResponse: ResponseType?
  
  func operation() async throws -> ResponseType {
    if shouldFail, let error = mockError {
      throw error
    }
    guard let response = mockResponse else {
      throw APIError.serverError(message: "No mock configured")
    }
    return response
  }
}

// 2. Use in tests
func testOperation() async throws {
  // Configure mock
  mockAPI.mockResponse = expectedData
  
  // Execute operation
  let result = try await viewModel.operation()
  
  // Verify state updates
  XCTAssertEqual(result, expectedData)
  XCTAssertEqual(viewModel.state, expectedState)
}
```

## Running Integration Tests

### Run all integration tests:
```bash
swift test --filter Integration
```

### Run specific workflow tests:
```bash
swift test --filter TaskLifecycleIntegrationTests
swift test --filter ChatMessagingIntegrationTests
swift test --filter MemoryCRUDIntegrationTests
```

### Run single test:
```bash
swift test --filter TaskLifecycleIntegrationTests/testTaskFullLifecycle
```

## Implementation Status

### ⚠️ Current State
These tests define the **expected behavior** and **test structure** but are not yet fully integrated with the actual `AppViewModel`.

**TODO for integration:**
1. Implement AppViewModel convenience init with mock injection
2. Implement missing AppViewModel methods (createTask, updateTaskStatus, etc.)
3. Update mock services to match actual APIService interface
4. Add actual state management logic to AppViewModel

**Why this approach?**
- Defines the test structure and patterns **first**
- Documents expected behavior clearly
- Allows parallel development of tests and implementation
- Tests serve as specification for AppViewModel methods

### Next Steps
1. **Review the test files** to understand expected workflows
2. **Implement AppViewModel methods** that match the test signatures
3. **Add dependency injection** to AppViewModel for mock services
4. **Run tests** and fix any failing assertions
5. **Expand tests** with additional edge cases

## Adding New Integration Tests

### Pattern to Follow

1. **Create test file** in `/Tests/LobsMissionControlTests/Integration/`
2. **Name convention:** `{Feature}IntegrationTests.swift`
3. **Document workflow** in file header (what's being tested, setup required)
4. **Create mock services** for API dependencies
5. **Write test cases** covering:
   - Happy path (full workflow)
   - Edge cases
   - Error handling
   - State consistency

### Example Structure

```swift
import XCTest
@testable import LobsMissionControl

/// Integration tests for {Feature} workflow
///
/// **Workflow Tested:**
/// 1. Step one
/// 2. Step two
/// 3. Step three
///
/// **Setup:**
/// - Mock services required
/// - Initial state expectations
final class FeatureIntegrationTests: XCTestCase {
  
  var mockAPI: MockFeatureAPI!
  var viewModel: AppViewModel!
  
  override func setUp() {
    super.setUp()
    mockAPI = MockFeatureAPI()
    viewModel = AppViewModel(featureAPI: mockAPI)
  }
  
  override func tearDown() {
    mockAPI = nil
    viewModel = nil
    super.tearDown()
  }
  
  // MARK: - Test Cases
  
  func testHappyPath() async throws {
    // GIVEN: Initial state
    // WHEN: Execute workflow
    // THEN: Verify expected state
  }
  
  func testErrorHandling() async {
    // GIVEN: Mock configured to fail
    // WHEN: Execute workflow
    // THEN: Error handled gracefully
  }
}

// MARK: - Mock Services

class MockFeatureAPI {
  var shouldFail = false
  var mockError: Error?
  var mockResponse: ResponseType?
  
  func operation() async throws -> ResponseType {
    if shouldFail, let error = mockError {
      throw error
    }
    guard let response = mockResponse else {
      throw APIError.serverError(message: "No mock configured")
    }
    return response
  }
}
```

## Best Practices

### 1. Test One Workflow Per File
Keep each test file focused on a single workflow. This makes tests easier to understand and maintain.

### 2. Use GIVEN/WHEN/THEN Comments
Structure tests clearly:
```swift
// GIVEN: Initial state and setup
// WHEN: Action being tested
// THEN: Expected outcome
```

### 3. Test State Consistency
Always verify that:
- API calls succeed
- ViewModel state updates correctly
- UI would reflect the change

### 4. Test Error Paths
Don't just test happy paths. Verify:
- API errors are caught
- State doesn't update on failure
- User-friendly errors are provided

### 5. Keep Tests Deterministic
- Use fixed timestamps when needed
- Don't rely on external state
- Mock all network calls

### 6. Document Edge Cases
If a test covers a specific edge case or bug fix, document it:
```swift
/// Test: Handle task completion with missing completedAt field
/// Regression: Previously crashed when server didn't set completedAt
func testCompletionWithMissingTimestamp() async throws {
  // ...
}
```

## Benefits of Integration Tests

### Catch Integration Bugs
Unit tests can miss bugs that only appear when components interact:
- JSON decoding issues (snake_case vs camelCase)
- State sync problems between UI and API
- WebSocket/REST API inconsistencies

### Document Workflows
Tests serve as executable documentation:
- Show how features are used end-to-end
- Demonstrate expected API contracts
- Provide examples for new developers

### Regression Prevention
Once a workflow is tested, regressions are caught immediately:
- Changes that break workflows fail tests
- Refactoring is safer
- API contract changes are detected

### Confidence in Changes
With integration tests:
- Refactor AppViewModel with confidence
- Update API client safely
- Change state management without breaking workflows

## Limitations

### Not a Replacement for E2E Tests
Integration tests use mocks, so they don't test:
- Actual server behavior
- Real network conditions
- Database constraints
- UI rendering

For full E2E coverage, consider:
- XCUITest for UI automation
- Live server integration tests
- Manual QA testing

### Maintenance Overhead
Integration tests need updates when:
- API contracts change
- AppViewModel structure changes
- Workflow requirements evolve

Keep tests in sync with implementation to avoid false failures.

## Resources

- **Swift Testing Docs:** https://developer.apple.com/documentation/xctest
- **Async Testing:** https://developer.apple.com/documentation/xctest/asynchronous_tests_and_expectations
- **Mock Pattern:** https://martinfowler.com/articles/mocksArentStubs.html

## Questions?

If you're extending these tests or adding new workflows:
1. Review existing test files for patterns
2. Follow the structure outlined above
3. Document your workflow clearly
4. Test both success and failure cases

---

**Last Updated:** 2026-02-22
**Status:** Test structure defined, awaiting AppViewModel implementation
