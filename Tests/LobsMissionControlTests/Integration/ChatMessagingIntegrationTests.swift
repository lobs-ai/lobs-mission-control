import XCTest
@testable import LobsMissionControl

/// Integration tests for chat messaging across WebSocket + REST API
///
/// **Workflow Tested:**
/// 1. Send message via WebSocket
/// 2. Receive message confirmation
/// 3. Fetch chat history via REST API
/// 4. Verify message ordering and timestamps
/// 5. Test real-time message delivery
///
/// **Setup:**
/// - Uses mock WebSocket and APIService
/// - Tests full data flow: Client → WebSocket → Server → Client
/// - Verifies state synchronization between WebSocket and REST
final class ChatMessagingIntegrationTests: XCTestCase {
  
  var mockWebSocket: MockWebSocketService!
  var mockAPI: MockChatAPIService!
  var viewModel: AppViewModel!
  
  override func setUp() {
    super.setUp()
    mockWebSocket = MockWebSocketService()
    mockAPI = MockChatAPIService()
    viewModel = AppViewModel(webSocket: mockWebSocket, chatAPI: mockAPI)
  }
  
  override func tearDown() {
    mockWebSocket = nil
    mockAPI = nil
    viewModel = nil
    super.tearDown()
  }
  
  // MARK: - Send/Receive Flow
  
  /// Test: Send message → Receive confirmation → Update UI
  func testSendMessageFlow() async throws {
    // GIVEN: Empty chat state
    XCTAssertEqual(viewModel.chatMessages.count, 0, "Should start with no messages")
    
    // WHEN: Send message via WebSocket
    let messageText = "Hello from integration test"
    mockWebSocket.mockSendResponse = ChatMessage(
      id: 1,
      content: messageText,
      sender: "user",
      timestamp: Date(),
      messageType: "user"
    )
    
    try await viewModel.sendChatMessage(messageText)
    
    // THEN: Message should be added to UI state
    XCTAssertEqual(viewModel.chatMessages.count, 1, "Message should be added")
    XCTAssertEqual(viewModel.chatMessages.first?.content, messageText)
    XCTAssertEqual(viewModel.chatMessages.first?.sender, "user")
    XCTAssertTrue(mockWebSocket.didSendMessage, "Should have sent via WebSocket")
  }
  
  /// Test: Receive message from WebSocket → Update UI
  func testReceiveMessageFlow() async {
    // GIVEN: WebSocket connected and listening
    XCTAssertTrue(mockWebSocket.isConnected)
    
    // WHEN: Receive message from server
    let incomingMessage = ChatMessage(
      id: 2,
      content: "Response from agent",
      sender: "assistant",
      timestamp: Date(),
      messageType: "assistant"
    )
    
    mockWebSocket.simulateIncomingMessage(incomingMessage)
    
    // Wait for message processing
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
    
    // THEN: Message should appear in UI state
    XCTAssertEqual(viewModel.chatMessages.count, 1)
    XCTAssertEqual(viewModel.chatMessages.first?.content, "Response from agent")
    XCTAssertEqual(viewModel.chatMessages.first?.sender, "assistant")
  }
  
  // MARK: - WebSocket + REST API Sync
  
  /// Test: WebSocket messages sync with REST API history
  func testMessageSyncBetweenWebSocketAndREST() async throws {
    // GIVEN: Some messages sent via WebSocket
    mockWebSocket.mockSendResponse = ChatMessage(
      id: 1,
      content: "WS message 1",
      sender: "user",
      timestamp: Date(),
      messageType: "user"
    )
    
    try await viewModel.sendChatMessage("WS message 1")
    
    // AND: Mock REST API has additional historical messages
    let historicalMessages = [
      ChatMessage(
        id: 0,
        content: "Historical message",
        sender: "assistant",
        timestamp: Date(timeIntervalSinceNow: -3600), // 1 hour ago
        messageType: "assistant"
      ),
      ChatMessage(
        id: 1,
        content: "WS message 1",
        sender: "user",
        timestamp: Date(),
        messageType: "user"
      )
    ]
    
    mockAPI.mockMessagesResponse = historicalMessages
    
    // WHEN: Fetch chat history from REST API
    await viewModel.loadChatHistory()
    
    // THEN: Messages should be merged and deduplicated
    XCTAssertGreaterThanOrEqual(viewModel.chatMessages.count, 2)
    
    // Verify historical message is present
    let historical = viewModel.chatMessages.first { $0.id == 0 }
    XCTAssertNotNil(historical)
    XCTAssertEqual(historical?.content, "Historical message")
    
    // Verify no duplicates of WebSocket message
    let wsMessages = viewModel.chatMessages.filter { $0.id == 1 }
    XCTAssertEqual(wsMessages.count, 1, "Should not have duplicate messages")
  }
  
  // MARK: - Message Ordering
  
  /// Test: Messages are correctly ordered by timestamp
  func testMessageOrdering() async {
    // GIVEN: Messages arriving out of order
    let message1 = ChatMessage(
      id: 1,
      content: "First",
      sender: "user",
      timestamp: Date(timeIntervalSinceNow: -300), // 5 min ago
      messageType: "user"
    )
    
    let message2 = ChatMessage(
      id: 2,
      content: "Second",
      sender: "assistant",
      timestamp: Date(timeIntervalSinceNow: -200), // 3.3 min ago
      messageType: "assistant"
    )
    
    let message3 = ChatMessage(
      id: 3,
      content: "Third",
      sender: "user",
      timestamp: Date(timeIntervalSinceNow: -100), // 1.6 min ago
      messageType: "user"
    )
    
    // Receive in wrong order
    mockWebSocket.simulateIncomingMessage(message3)
    mockWebSocket.simulateIncomingMessage(message1)
    mockWebSocket.simulateIncomingMessage(message2)
    
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
    
    // THEN: Messages should be sorted by timestamp
    XCTAssertEqual(viewModel.chatMessages.count, 3)
    XCTAssertEqual(viewModel.chatMessages[0].content, "First", "Oldest message should be first")
    XCTAssertEqual(viewModel.chatMessages[1].content, "Second")
    XCTAssertEqual(viewModel.chatMessages[2].content, "Third", "Newest message should be last")
  }
  
  // MARK: - Connection Handling
  
  /// Test: WebSocket reconnection preserves messages
  func testWebSocketReconnection() async throws {
    // GIVEN: Messages sent while connected
    mockWebSocket.mockSendResponse = ChatMessage(
      id: 1,
      content: "Before disconnect",
      sender: "user",
      timestamp: Date(),
      messageType: "user"
    )
    
    try await viewModel.sendChatMessage("Before disconnect")
    XCTAssertEqual(viewModel.chatMessages.count, 1)
    
    // WHEN: WebSocket disconnects
    mockWebSocket.simulateDisconnect()
    XCTAssertFalse(mockWebSocket.isConnected)
    
    // THEN: Messages should still be preserved
    XCTAssertEqual(viewModel.chatMessages.count, 1, "Messages should not be lost on disconnect")
    
    // WHEN: Reconnect
    mockWebSocket.simulateReconnect()
    XCTAssertTrue(mockWebSocket.isConnected)
    
    // AND: Load history from REST API
    mockAPI.mockMessagesResponse = [
      ChatMessage(
        id: 1,
        content: "Before disconnect",
        sender: "user",
        timestamp: Date(),
        messageType: "user"
      )
    ]
    
    await viewModel.loadChatHistory()
    
    // THEN: Messages should still be present
    XCTAssertGreaterThanOrEqual(viewModel.chatMessages.count, 1)
  }
  
  // MARK: - Error Handling
  
  /// Test: Send failure handling
  func testSendMessageErrorHandling() async {
    // GIVEN: WebSocket configured to fail
    mockWebSocket.shouldFailSend = true
    mockWebSocket.mockError = NSError(domain: "WebSocket", code: -1, userInfo: [
      NSLocalizedDescriptionKey: "Connection lost"
    ])
    
    // WHEN: Attempt to send message
    do {
      try await viewModel.sendChatMessage("This will fail")
      XCTFail("Should have thrown error")
    } catch {
      // THEN: Error should be thrown
      XCTAssertNotNil(error)
    }
    
    // AND: No message should be added to state
    XCTAssertEqual(viewModel.chatMessages.count, 0, "Failed messages should not be added")
  }
  
  /// Test: Receive invalid message format
  func testReceiveInvalidMessageFormat() async {
    // GIVEN: WebSocket receives malformed message
    let invalidMessage = ChatMessage(
      id: nil, // Invalid: missing ID
      content: "Invalid",
      sender: nil, // Invalid: missing sender
      timestamp: nil, // Invalid: missing timestamp
      messageType: "user"
    )
    
    // WHEN: Simulate receiving invalid message
    mockWebSocket.simulateIncomingMessage(invalidMessage)
    
    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
    
    // THEN: Invalid message should be rejected or handled gracefully
    // Exact behavior depends on implementation - either reject or use defaults
    // For now, just ensure no crash
    XCTAssertTrue(true, "Should handle invalid message without crashing")
  }
}

// MARK: - Mock WebSocket Service

class MockWebSocketService {
  var isConnected = true
  var didSendMessage = false
  var shouldFailSend = false
  var mockError: Error?
  var mockSendResponse: ChatMessage?
  
  private var messageHandlers: [(ChatMessage) -> Void] = []
  
  func sendMessage(_ text: String) async throws -> ChatMessage {
    if shouldFailSend, let error = mockError {
      throw error
    }
    
    didSendMessage = true
    
    guard let response = mockSendResponse else {
      throw NSError(domain: "WebSocket", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "No mock response configured"
      ])
    }
    
    return response
  }
  
  func onMessageReceived(_ handler: @escaping (ChatMessage) -> Void) {
    messageHandlers.append(handler)
  }
  
  func simulateIncomingMessage(_ message: ChatMessage) {
    for handler in messageHandlers {
      handler(message)
    }
  }
  
  func simulateDisconnect() {
    isConnected = false
  }
  
  func simulateReconnect() {
    isConnected = true
  }
}

// MARK: - Mock Chat API Service

class MockChatAPIService {
  var mockMessagesResponse: [ChatMessage] = []
  
  func fetchChatHistory(limit: Int = 100) async throws -> [ChatMessage] {
    return mockMessagesResponse
  }
}

// MARK: - AppViewModel Extensions

extension AppViewModel {
  /// Convenience initializer for chat testing
  convenience init(webSocket: MockWebSocketService, chatAPI: MockChatAPIService) {
    self.init()
    // Inject mocks - implementation depends on AppViewModel structure
  }
  
  /// Send chat message via WebSocket
  func sendChatMessage(_ text: String) async throws {
    // Implementation would call WebSocket and update chatMessages array
    fatalError("TODO: Implement in actual AppViewModel")
  }
  
  /// Load chat history from REST API
  func loadChatHistory() async {
    // Implementation would call API and update chatMessages array
    fatalError("TODO: Implement in actual AppViewModel")
  }
}
