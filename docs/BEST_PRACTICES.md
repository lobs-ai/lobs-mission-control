# Best Practices for lobs-mission-control

**Last Updated:** 2026-02-14  
**Audience:** Developers, AI programmer agents  
**Purpose:** Swift/SwiftUI patterns, concurrency best practices, and code quality guidelines

---

## Table of Contents

1. [Swift Concurrency](#swift-concurrency)
2. [SwiftUI Patterns](#swiftui-patterns)
3. [State Management](#state-management)
4. [API Integration](#api-integration)
5. [Code Quality](#code-quality)
6. [Common Pitfalls](#common-pitfalls)

---

## Swift Concurrency

### Actor Isolation (Critical)

**Problem:** Calling `@MainActor`-isolated methods from non-isolated contexts causes race conditions.

```swift
// ❌ BAD - Actor isolation violation
NotificationCenter.default.addObserver(...) { [weak self] _ in
    self?.pause()  // ⚠️ pause() is @MainActor but context is not
}

// ✅ GOOD - Properly isolated
NotificationCenter.default.addObserver(...) { [weak self] _ in
    Task { @MainActor in
        self?.pause()
    }
}
```

**Rule:** If a method is `@MainActor` or part of a `@MainActor` class, all calls must be from `@MainActor` context.

### MainActor Annotations

**When to use `@MainActor`:**

```swift
// ✅ UI-related classes should be @MainActor
@MainActor
class AppViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var selectedTask: Task?
    
    func updateUI() {
        // Safe to update @Published properties
        // Already on main actor
    }
}

// ✅ View models that update UI state
@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [Event] = []
}
```

**When NOT to use `@MainActor`:**

```swift
// ✅ API/network layer should NOT be @MainActor
class APIService {
    // Network calls should be on background threads
    func fetchTasks() async throws -> [Task] {
        // This runs on background thread by default
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Task].self, from: data)
    }
}
```

### Async/Await Patterns

```swift
// ✅ Good async pattern
func loadData() async {
    do {
        let tasks = try await apiService.fetchTasks()
        
        // Update UI on main actor
        await MainActor.run {
            self.tasks = tasks
        }
    } catch {
        await MainActor.run {
            self.error = error.localizedDescription
        }
    }
}

// ✅ SwiftUI Task modifier
.task {
    await loadData()
}

// ❌ Bad - using onAppear with async
.onAppear {
    Task {
        await loadData()  // Works but .task is clearer
    }
}
```

### Unnecessary Await

**Problem:** Using `await` on synchronous functions creates warnings.

```swift
// ❌ BAD - Function is not async
func loadAgentDocuments() {
    // Synchronous work
}

// In caller:
await vm.loadAgentDocuments()  // ⚠️ Warning: no async operations

// ✅ GOOD - Remove await
vm.loadAgentDocuments()

// OR make function truly async if it should be:
func loadAgentDocuments() async {
    let docs = try await apiService.fetchDocuments()
    self.documents = docs
}
```

---

## SwiftUI Patterns

### onChange API (Modern)

**Old API (Deprecated in macOS 14.0):**

```swift
// ❌ DEPRECATED
.onChange(of: searchText) { newValue in
    selectedIndex = 0
}
```

**New API (macOS 14.0+):**

```swift
// ✅ Two-parameter version (when you need old value)
.onChange(of: searchText) { oldValue, newValue in
    if oldValue != newValue {
        selectedIndex = 0
    }
}

// ✅ Zero-parameter version (when you don't need values)
.onChange(of: searchText) {
    selectedIndex = 0
}
```

**Migration rule:**
- Use **zero-parameter** when you only care that something changed
- Use **two-parameter** when you need old/new values for comparison

### State Management Hierarchy

```swift
// ✅ Correct state ownership

// 1. @StateObject - View owns the object lifecycle
struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
}

// 2. @ObservedObject - Parent owns it, passed down
struct TaskDetailView: View {
    @ObservedObject var viewModel: TaskListViewModel
}

// 3. @EnvironmentObject - App-wide state
struct AnyView: View {
    @EnvironmentObject var appViewModel: AppViewModel
}

// 4. @State - View-local simple state
struct SearchBar: View {
    @State private var searchText = ""
}
```

**Rules:**
- `@StateObject` = **I own this object**
- `@ObservedObject` = **Someone else owns this object**
- `@EnvironmentObject` = **App-wide shared state**
- `@State` = **Simple value type state**

### View Composition

Break large views into smaller, focused components:

```swift
// ❌ BAD - 500+ line view file
struct TaskListView: View {
    var body: some View {
        VStack {
            // 50 lines of search UI
            // 100 lines of filters
            // 200 lines of list
            // 100 lines of footer
        }
    }
}

// ✅ GOOD - Composed views
struct TaskListView: View {
    var body: some View {
        VStack {
            TaskSearchBar()
            TaskFilters()
            TaskList()
            TaskFooter()
        }
    }
}

// Each component is 50-100 lines, focused, reusable
```

**Target:** Keep view files under 200 lines when possible.

### Navigation Patterns

```swift
// ✅ Modern NavigationStack (macOS 13+)
NavigationStack {
    TaskListView()
        .navigationDestination(for: Task.self) { task in
            TaskDetailView(task: task)
        }
}

// ❌ Old NavigationView (deprecated)
NavigationView {
    TaskListView()
}
```

**Use NavigationStack for:**
- Push/pop navigation
- Deep linking
- Type-safe navigation paths

---

## State Management

### AppViewModel Pattern

**Single source of truth for app-wide state:**

```swift
@MainActor
class AppViewModel: ObservableObject {
    // Published state
    @Published var tasks: [Task] = []
    @Published var selectedTask: Task?
    @Published var isLoading = false
    
    // Dependencies
    let apiService: APIService
    
    init(apiService: APIService = APIService()) {
        self.apiService = apiService
    }
    
    // Actions
    func loadTasks() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            tasks = try await apiService.fetchTasks()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

**Inject at app root:**

```swift
@main
struct LobsMissionControlApp: App {
    @StateObject private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appViewModel)
        }
    }
}
```

**Access in views:**

```swift
struct TaskListView: View {
    @EnvironmentObject var vm: AppViewModel
    
    var body: some View {
        List(vm.tasks) { task in
            TaskRow(task: task)
        }
        .task {
            await vm.loadTasks()
        }
    }
}
```

### Derived State

Use computed properties for derived state:

```swift
class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var filter: TaskFilter = .all
    
    // ✅ Derived state (not stored)
    var filteredTasks: [Task] {
        tasks.filter { task in
            switch filter {
            case .all: return true
            case .active: return !task.completed
            case .completed: return task.completed
            }
        }
    }
}
```

**Don't:**
```swift
// ❌ BAD - Duplicating state
@Published var tasks: [Task] = []
@Published var filteredTasks: [Task] = []  // Can get out of sync!
```

---

## API Integration

### Codable Models

```swift
// ✅ Good model design
struct Task: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let status: TaskStatus
    let owner: String?  // ← Optional if API can return null
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case status
        case owner
        case createdAt = "created_at"  // ← Snake case mapping
    }
}
```

**JSONDecoder configuration:**

```swift
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase  // Auto snake_case → camelCase
decoder.dateDecodingStrategy = .iso8601
```

### Error Handling

```swift
// ✅ Good error handling
func fetchTasks() async throws -> [Task] {
    let url = URL(string: "\(baseURL)/api/tasks")!
    var request = URLRequest(url: url)
    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.invalidResponse
    }
    
    guard httpResponse.statusCode == 200 else {
        throw APIError.httpError(statusCode: httpResponse.statusCode)
    }
    
    return try decoder.decode([Task].self, from: data)
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error: \(code)"
        }
    }
}
```

### WebSocket Patterns

```swift
class ChatService: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    
    func connect() {
        let url = URL(string: "ws://localhost:8000/ws/chat")!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage()  // Continue listening
            case .failure(let error):
                print("WebSocket error: \(error)")
                self?.reconnect()
            }
        }
    }
    
    func reconnect() {
        // Exponential backoff
        Task {
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            connect()
        }
    }
}
```

---

## Code Quality

### Unused Variables

```swift
// ❌ BAD - Variable checked but not used
guard let repoURL = vm.repoURL else { return }
// repoURL is never used after this

// ✅ GOOD - Just check existence
guard vm.repoURL != nil else { return }

// OR if you actually need it:
guard let repoURL = vm.repoURL else { return }
openInBrowser(url: repoURL)  // Actually use it
```

### Optional Handling

```swift
// ✅ Safe unwrapping patterns

// 1. Guard let for early exit
guard let task = selectedTask else { return }
performAction(on: task)

// 2. If let for conditional logic
if let task = selectedTask {
    performAction(on: task)
}

// 3. Nil coalescing for defaults
let taskOwner = task.owner ?? "Unassigned"

// 4. Optional chaining
task?.subtasks?.forEach { ... }

// ❌ Don't force unwrap unless you're 100% certain
let task = selectedTask!  // Avoid
```

### Type Inference vs. Explicit Types

```swift
// ✅ Let Swift infer when obvious
let tasks = vm.tasks.filter { $0.completed }
let count = tasks.count

// ✅ Be explicit when it helps readability
let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

// Function parameters and returns should always be explicit
func filterTasks(_ tasks: [Task], by status: TaskStatus) -> [Task] {
    tasks.filter { $0.status == status }
}
```

---

## Common Pitfalls

### 1. Actor Isolation Violations

**Problem:** Calling `@MainActor` methods from non-isolated context.

**Solution:** Wrap in `Task { @MainActor in }` or mark context as `@MainActor`.

### 2. Using Deprecated onChange

**Problem:** Using old `onChange(of:perform:)` API.

**Solution:** Migrate to `onChange(of:) { }` (zero-parameter) or `onChange(of:) { old, new in }` (two-parameter).

### 3. Forgetting to Remove Await

**Problem:** Using `await` on synchronous functions.

**Solution:** Remove `await` or make function truly async.

### 4. Mixing @StateObject and @ObservedObject

**Problem:** Using `@ObservedObject` when the view should own the object.

**Solution:**
- `@StateObject` = View creates and owns the object
- `@ObservedObject` = Object is passed from parent

### 5. Force Unwrapping Optionals

**Problem:** Using `!` to force unwrap can crash if value is nil.

**Solution:** Use `guard let`, `if let`, or nil coalescing (`??`).

### 6. Not Handling API Errors

**Problem:** Not showing user-friendly error messages.

**Solution:**
```swift
func loadTasks() async {
    do {
        tasks = try await apiService.fetchTasks()
    } catch {
        errorMessage = "Failed to load tasks: \(error.localizedDescription)"
        showError = true
    }
}
```

---

## Quick Reference

### Starting a New View

1. ✅ Decide on state ownership (`@State`, `@StateObject`, `@EnvironmentObject`)
2. ✅ Mark ViewModels as `@MainActor`
3. ✅ Use `.task { }` for async work, not `.onAppear { Task { } }`
4. ✅ Use modern `onChange` API (zero or two-parameter)
5. ✅ Handle loading and error states
6. ✅ Keep view under 200 lines (compose if larger)

### Before Committing

- [ ] No actor isolation warnings
- [ ] No deprecated API warnings (onChange, NavigationView)
- [ ] No unused variable warnings
- [ ] No force unwraps (`!`) in production code
- [ ] Error states handled gracefully
- [ ] Async functions properly awaited

---

## Resources

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) — Official Swift guide
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui) — Apple's SwiftUI docs
- [MainActor Deep Dive](https://www.swiftbysundell.com/articles/the-main-actor-attribute/) — Swift by Sundell
- [Project KNOWN_ISSUES.md](KNOWN_ISSUES.md) — Current issues and tech debt
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Development guide

---

**Questions?** Check [docs/README.md](README.md) for full documentation index.

**Last Updated:** 2026-02-14
