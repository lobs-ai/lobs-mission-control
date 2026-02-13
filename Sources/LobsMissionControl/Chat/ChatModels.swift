import Foundation

// MARK: - Chat Session
// Note: No CodingKeys needed — APIService decoder uses .convertFromSnakeCase
// For WebSocket decoding (plain JSONDecoder), the custom init on ChatWebSocketEvent handles field mapping

struct ChatSession: Identifiable, Codable, Equatable {
    let id: String
    let sessionKey: String
    var label: String?
    let createdAt: Date
    var isActive: Bool
    var lastMessageAt: Date?
    
    var displayLabel: String {
        label ?? sessionKey
    }
    
    // Manual decoding to handle both APIService (.convertFromSnakeCase) and WebSocket (plain) decoders
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexCodingKeys.self)
        id = try container.decode(String.self, forKey: .init("id"))
        // Try camelCase first (from .convertFromSnakeCase decoder), then snake_case (from plain decoder)
        sessionKey = try (try? container.decode(String.self, forKey: .init("sessionKey"))) ?? container.decode(String.self, forKey: .init("session_key"))
        label = try? container.decodeIfPresent(String.self, forKey: .init("label"))
        createdAt = try (try? container.decode(Date.self, forKey: .init("createdAt"))) ?? container.decode(Date.self, forKey: .init("created_at"))
        isActive = try (try? container.decode(Bool.self, forKey: .init("isActive"))) ?? (try? container.decode(Bool.self, forKey: .init("is_active"))) ?? true
        lastMessageAt = try? (try? container.decodeIfPresent(Date.self, forKey: .init("lastMessageAt"))) ?? container.decodeIfPresent(Date.self, forKey: .init("last_message_at"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: FlexCodingKeys.self)
        try container.encode(id, forKey: .init("id"))
        try container.encode(sessionKey, forKey: .init("session_key"))
        try container.encodeIfPresent(label, forKey: .init("label"))
        try container.encode(createdAt, forKey: .init("created_at"))
        try container.encode(isActive, forKey: .init("is_active"))
        try container.encodeIfPresent(lastMessageAt, forKey: .init("last_message_at"))
    }
    
    init(id: String, sessionKey: String, label: String? = nil, createdAt: Date, isActive: Bool = true, lastMessageAt: Date? = nil) {
        self.id = id
        self.sessionKey = sessionKey
        self.label = label
        self.createdAt = createdAt
        self.isActive = isActive
        self.lastMessageAt = lastMessageAt
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let role: MessageRole
    let content: String
    let createdAt: Date
    let messageMetadata: [String: String]?
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    var isFromUser: Bool {
        role == .user
    }
    
    // Manual decoding to handle both decoders
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexCodingKeys.self)
        id = try container.decode(String.self, forKey: .init("id"))
        role = try container.decode(MessageRole.self, forKey: .init("role"))
        content = try container.decode(String.self, forKey: .init("content"))
        createdAt = try (try? container.decode(Date.self, forKey: .init("createdAt"))) ?? container.decode(Date.self, forKey: .init("created_at"))
        messageMetadata = try? (try? container.decodeIfPresent([String: String].self, forKey: .init("messageMetadata"))) ?? container.decodeIfPresent([String: String].self, forKey: .init("message_metadata"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: FlexCodingKeys.self)
        try container.encode(id, forKey: .init("id"))
        try container.encode(role, forKey: .init("role"))
        try container.encode(content, forKey: .init("content"))
        try container.encode(createdAt, forKey: .init("created_at"))
        try container.encodeIfPresent(messageMetadata, forKey: .init("message_metadata"))
    }
    
    init(id: String, role: MessageRole, content: String, createdAt: Date, messageMetadata: [String: String]? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.messageMetadata = messageMetadata
    }
}

// MARK: - Flexible CodingKeys (handles both snake_case and camelCase)

struct FlexCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - WebSocket Events

enum ChatWebSocketEvent: Codable {
    case connected(sessionKey: String)
    case message(ChatMessage)
    case typingStart
    case typingStop
    case sessionList([ChatSession])
    case sessionCreated(ChatSession)
    case error(String)
    
    private enum TypeCodingKeys: String, CodingKey {
        case type
        case sessionKey = "session_key"
        case data
        case message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: TypeCodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "connected":
            let sessionKey = try container.decode(String.self, forKey: .sessionKey)
            self = .connected(sessionKey: sessionKey)
        case "message":
            let messageData = try container.decode(ChatMessage.self, forKey: .data)
            self = .message(messageData)
        case "typing_start":
            self = .typingStart
        case "typing_stop":
            self = .typingStop
        case "session_list":
            let sessions = try container.decode([ChatSession].self, forKey: .data)
            self = .sessionList(sessions)
        case "session_created":
            let session = try container.decode(ChatSession.self, forKey: .data)
            self = .sessionCreated(session)
        case "error":
            let errorMessage = try container.decode(String.self, forKey: .message)
            self = .error(errorMessage)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown event type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: TypeCodingKeys.self)
        switch self {
        case .connected(let sessionKey):
            try container.encode("connected", forKey: .type)
            try container.encode(sessionKey, forKey: .sessionKey)
        case .message(let message):
            try container.encode("message", forKey: .type)
            try container.encode(message, forKey: .data)
        case .typingStart:
            try container.encode("typing_start", forKey: .type)
        case .typingStop:
            try container.encode("typing_stop", forKey: .type)
        case .sessionList(let sessions):
            try container.encode("session_list", forKey: .type)
            try container.encode(sessions, forKey: .data)
        case .sessionCreated(let session):
            try container.encode("session_created", forKey: .type)
            try container.encode(session, forKey: .data)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        }
    }
}

// MARK: - Outgoing Events

enum ChatOutgoingEvent: Encodable {
    case sendMessage(content: String, sessionKey: String?)
    case createSession(label: String, sessionKey: String?)
    case listSessions
    case switchSession(sessionKey: String)
    
    var jsonData: Data? {
        try? JSONEncoder().encode(self)
    }
    
    private enum OutCodingKeys: String, CodingKey {
        case type
        case content
        case sessionKey = "session_key"
        case label
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutCodingKeys.self)
        switch self {
        case .sendMessage(let content, let sessionKey):
            try container.encode("send_message", forKey: .type)
            try container.encode(content, forKey: .content)
            if let sk = sessionKey { try container.encode(sk, forKey: .sessionKey) }
        case .createSession(let label, let sessionKey):
            try container.encode("create_session", forKey: .type)
            try container.encode(label, forKey: .label)
            if let sk = sessionKey { try container.encode(sk, forKey: .sessionKey) }
        case .listSessions:
            try container.encode("list_sessions", forKey: .type)
        case .switchSession(let sessionKey):
            try container.encode("switch_session", forKey: .type)
            try container.encode(sessionKey, forKey: .sessionKey)
        }
    }
}

// MARK: - Connection State

enum ChatConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(sessionKey: String)
    case reconnecting
    case error(String)
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var statusText: String {
        switch self {
        case .disconnected: return "Not connected"
        case .connecting: return "Connecting..."
        case .connected(let sk): return "Connected to \(sk)"
        case .reconnecting: return "Reconnecting..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
