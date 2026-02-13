import SwiftUI
import AppKit

/// Text input bar for sending chat messages
struct ChatInputView: View {
    @Binding var text: String
    let isConnected: Bool
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Text input with Enter-to-send behavior
            EnterToSendChatInput(
                text: $text,
                isEnabled: isConnected,
                onSend: sendMessage
            )
            .frame(minHeight: 36, maxHeight: 120)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(18)
            .opacity(isConnected ? 1.0 : 0.5)
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.body)
                    .foregroundColor(canSend ? .blue : .gray)
                    .frame(width: 36, height: 36)
                    .background(canSend ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(18)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var canSend: Bool {
        isConnected && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard canSend else { return }
        onSend()
        text = ""
    }
}

// MARK: - Enter-to-Send Chat Input

/// Custom NSTextView wrapper that sends on Enter and inserts newline on Shift+Enter
private struct EnterToSendChatInput: NSViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool
    var onSend: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 4
        textView.textContainerInset = NSSize(width: 4, height: 6)
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        textView.isEditable = isEnabled
        textView.isSelectable = isEnabled
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EnterToSendChatInput
        
        init(_ parent: EnterToSendChatInput) {
            self.parent = parent
        }
        
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check for shift key
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    // Shift+Enter: insert newline
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                // Plain Enter: send message
                parent.onSend()
                return true
            }
            return false
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
