# Testing Guide — lobs-mission-control

**Last Updated:** 2026-02-14

Guide for running and writing tests for the Lobs Mission Control macOS app.

---

## Quick Start

```bash
cd ~/lobs-mission-control

# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter <TestName>
```

---

## Current Test Status

⚠️ **Test build is currently broken** — See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for details

**Issue:** Multiple products error when running `swift test`

**Handoff:** `handoff-mission-control-test-build.json` (in self-improvement project)

---

## Test Structure

```
Tests/
└── LobsMissionControlTests/
    └── LobsMissionControlTests.swift
```

Tests are organized using Swift Package Manager's standard test layout.

---

## Writing Tests

### Basic Test Example

```swift
import XCTest
@testable import LobsMissionControl

final class MyFeatureTests: XCTestCase {
    
    func testBasicFunctionality() {
        // Arrange
        let sut = MyFeature()
        
        // Act
        let result = sut.doSomething()
        
        // Assert
        XCTAssertEqual(result, expectedValue)
    }
}
```

### Testing Async/Await Code

```swift
func testAsyncOperation() async throws {
    let sut = MyAsyncService()
    
    let result = await sut.fetchData()
    
    XCTAssertNotNil(result)
}
```

### Testing MainActor-Isolated Code

```swift
@MainActor
func testMainActorCode() {
    let viewModel = AppViewModel()
    
    viewModel.updateState()
    
    XCTAssertEqual(viewModel.state, .updated)
}
```

---

## Test Patterns

### ViewModels

**Testing state changes:**
```swift
func testViewModelStateChange() {
    let viewModel = MyViewModel()
    
    viewModel.performAction()
    
    XCTAssertEqual(viewModel.currentState, .expectedState)
}
```

**Testing async operations:**
```swift
func testAsyncDataLoad() async {
    let viewModel = MyViewModel()
    
    await viewModel.loadData()
    
    XCTAssertFalse(viewModel.items.isEmpty)
}
```

### Network Calls

**Mock the API service:**
```swift
class MockAPIService: APIServiceProtocol {
    var shouldSucceed = true
    
    func fetchTasks() async throws -> [Task] {
        if shouldSucceed {
            return [Task(id: 1, title: "Test")]
        } else {
            throw NetworkError.failed
        }
    }
}

func testNetworkSuccess() async throws {
    let mockAPI = MockAPIService()
    let viewModel = TaskViewModel(apiService: mockAPI)
    
    await viewModel.loadTasks()
    
    XCTAssertEqual(viewModel.tasks.count, 1)
}
```

### SwiftUI Views

**Snapshot testing or logic extraction:**

Since SwiftUI views are difficult to test directly, extract testable logic:

```swift
// ❌ Hard to test
struct MyView: View {
    var body: some View {
        Text(isValid ? "Valid" : "Invalid")
    }
    
    private var isValid: Bool {
        // Complex validation logic
    }
}

// ✅ Easy to test
struct MyView: View {
    @StateObject private var viewModel: MyViewModel
    
    var body: some View {
        Text(viewModel.validationMessage)
    }
}

class MyViewModel: ObservableObject {
    var validationMessage: String {
        isValid ? "Valid" : "Invalid"
    }
    
    func isValid() -> Bool {
        // Complex validation logic - now testable!
    }
}
```

---

## Testing Best Practices

### DO

✅ **Test business logic, not UI**
- Extract logic from views into view models
- Test view model state changes and calculations

✅ **Use dependency injection**
- Pass services/APIs as parameters
- Makes mocking easy

✅ **Test async code properly**
- Use `async` test methods
- Use `await` for async operations
- Handle errors with `throws`

✅ **Test actor isolation**
- Mark test methods `@MainActor` when testing MainActor code
- Use `Task { @MainActor in }` when needed

✅ **Keep tests focused**
- One concept per test
- Clear arrange/act/assert structure
- Descriptive test names

### DON'T

❌ **Don't test SwiftUI views directly**
- Views change frequently
- Hard to verify rendering
- Extract logic instead

❌ **Don't test Apple frameworks**
- Trust that URLSession works
- Test your code that uses URLSession

❌ **Don't use global state**
- Makes tests interdependent
- Hard to isolate failures

❌ **Don't ignore actor isolation warnings**
- Fixing warnings prevents concurrency bugs
- Use proper `@MainActor` annotations

---

## Running Tests

### Command Line

```bash
# All tests
swift test

# Verbose output (shows individual test results)
swift test --verbose

# Specific test class
swift test --filter MyFeatureTests

# Specific test method
swift test --filter MyFeatureTests/testSpecificThing

# Parallel execution (default)
swift test --parallel

# Serial execution (for debugging)
swift test --parallel --num-workers 1
```

### Xcode

1. Open `Package.swift` in Xcode
2. Navigate to test navigator (⌘6)
3. Click diamond icon next to test to run it
4. Or: Product → Test (⌘U)

---

## Test Coverage

Currently, test coverage is minimal. Priorities for adding tests:

1. **Critical business logic** — Task management, API service
2. **Data transformations** — Response parsing, model mapping
3. **State management** — View model state changes
4. **Error handling** — Network failures, invalid data

**Future:** Consider adding test coverage tracking:
```bash
swift test --enable-code-coverage
```

---

## Troubleshooting

### "Multiple products" error

**Problem:** `swift test` fails with "multiple products" error

**Status:** Known issue - see [KNOWN_ISSUES.md](KNOWN_ISSUES.md)

**Workaround:** Fix pending in handoff `handoff-mission-control-test-build.json`

### "Call to main actor-isolated method" warnings

**Problem:** Compiler warnings about MainActor isolation

**Solution:** Wrap calls in `Task { @MainActor in }`

```swift
// ❌ Warning
someMethod()

// ✅ Fixed
Task { @MainActor in
    someMethod()
}
```

Or mark test method as `@MainActor`:
```swift
@MainActor
func testMainActorCode() {
    someMethod()  // ✅ Now in MainActor context
}
```

### Tests timing out

**Problem:** Async tests hang or timeout

**Solution:** Use proper `await` and check for deadlocks:

```swift
// ❌ Will hang
func testAsync() {
    Task {
        await doSomething()
    }
    // Test completes before Task finishes!
}

// ✅ Proper async test
func testAsync() async {
    await doSomething()
    // Test waits for completion
}
```

---

## Related Documentation

- **[KNOWN_ISSUES.md](KNOWN_ISSUES.md)** — Current test build issues
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** — App architecture and components
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** — Development workflow
- **[lobs-server/docs/TESTING.md](../../lobs-server/docs/TESTING.md)** — Backend testing guide (similar patterns)

---

## Future Improvements

- [ ] Fix test build (handoff pending)
- [ ] Add test coverage tracking
- [ ] Create mock API service for all endpoints
- [ ] Add UI snapshot testing (optional)
- [ ] Add integration tests for WebSocket
- [ ] Document testing patterns for specific features

---

**Last updated:** 2026-02-14
