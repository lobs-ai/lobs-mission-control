import SwiftUI
import AppKit

// MARK: - Documents View

struct DocumentsView: View {
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool

  @State private var selectedDocument: AgentDocument? = nil
  @State private var selectedTopicOrGroup: String? = nil
  @State private var searchText: String = ""
  @State private var userNotes: String = ""
  @State private var expandedTopics: Set<String> = []
  @State private var showFollowUpSheet: Bool = false
  @AppStorage("documentsShowReadItems") private var showReadItems: Bool = true
  @AppStorage("documentsShowStarredOnly") private var showStarredOnly: Bool = false
  @AppStorage("documentsGroupByTopic") private var groupByTopic: Bool = true

  // Topic groups for the sidebar
  private var topicGroups: [(String, [AgentDocument], Int)] {
    guard groupByTopic else { return [] }
    
    var groups: [(String, [AgentDocument], Int)] = []
    
    // Reports section (all writer documents)
    let reports = filteredDocuments.filter { $0.source == .writer }
    if !reports.isEmpty {
      let unreadCount = reports.filter { !$0.isRead }.count
      groups.append(("Reports", reports, unreadCount))
    }
    
    // Research sections grouped by topic
    let researchDocs = filteredDocuments.filter { $0.source == .researcher }
    let topicMap = Dictionary(grouping: researchDocs) { $0.topic ?? "Other" }
    
    for (topic, docs) in topicMap.sorted(by: { $0.key < $1.key }) {
      let unreadCount = docs.filter { !$0.isRead }.count
      groups.append((topic, docs, unreadCount))
    }
    
    return groups
  }
  
  // Filtered documents for current selection
  private var documentsForCurrentView: [AgentDocument] {
    if !groupByTopic {
      return filteredDocuments
    }
    
    guard let selected = selectedTopicOrGroup else {
      return filteredDocuments
    }
    
    if selected == "Reports" {
      return filteredDocuments.filter { $0.source == .writer }
    } else {
      return filteredDocuments.filter { $0.topic == selected }
    }
  }

  private var filteredDocuments: [AgentDocument] {
    var docs = vm.agentDocuments

    // Filter by starred status
    if showStarredOnly {
      docs = docs.filter { $0.isStarred }
    }

    // Filter by read status
    if !showReadItems {
      docs = docs.filter { !$0.isRead }
    }

    // Filter by search text
    let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !q.isEmpty {
      docs = docs.filter { doc in
        doc.title.lowercased().contains(q)
          || doc.filename.lowercased().contains(q)
          || (doc.topic?.lowercased().contains(q) ?? false)
          || (doc.summary?.lowercased().contains(q) ?? false)
      }
    }

    return docs.sorted { $0.date > $1.date }
  }

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "doc.text.fill")
            .font(.title2)
            .foregroundStyle(.linearGradient(
              colors: [.purple, .pink],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("Documents")
            .font(.title3)
            .fontWeight(.bold)

          if vm.agentDocuments.filter({ !$0.isRead }).count > 0 {
            Text("\(vm.agentDocuments.filter({ !$0.isRead }).count) new")
              .font(.system(size: 11, weight: .semibold))
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(Color.purple.opacity(0.15))
              .foregroundStyle(.purple)
              .clipShape(Capsule())
          }
        }

        Spacer()

        // Close button
        Button {
          isPresented = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Close")
      }
      .padding()

      Divider()

      // Toolbar
      HStack(spacing: 12) {
        // Search
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Search documents...", text: $searchText)
            .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)

        // Starred filter toggle
        Toggle(isOn: $showStarredOnly) {
          HStack(spacing: 4) {
            Image(systemName: showStarredOnly ? "star.fill" : "star")
            Text(showStarredOnly ? "All Docs" : "Starred")
          }
          .font(.system(size: 13))
        }
        .toggleStyle(.button)
        .foregroundStyle(showStarredOnly ? .yellow : .primary)

        // Read filter toggle
        Toggle(isOn: $showReadItems) {
          HStack(spacing: 4) {
            Image(systemName: showReadItems ? "eye" : "eye.slash")
            Text(showReadItems ? "Hide Read" : "Show All")
          }
          .font(.system(size: 13))
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .help(showReadItems ? "Hide read documents" : "Show all documents")

        Spacer()

        // Document count
        Text("\(filteredDocuments.count) document\(filteredDocuments.count == 1 ? "" : "s")")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal)
      .padding(.vertical, 8)

      Divider()

      // Content - Split view (single list + detail)
      HSplitView {
        // Left: Document list grouped by topic
        ScrollView {
          LazyVStack(spacing: 0) {
            if filteredDocuments.isEmpty {
              VStack(spacing: 12) {
                Image(systemName: "doc.text")
                  .font(.system(size: 48))
                  .foregroundStyle(.secondary)
                Text("No documents")
                  .font(.headline)
                Text(searchText.isEmpty ? "Agent documents will appear here" : "No documents match your filters")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 60)
            } else {
              ForEach(topicGroups, id: \.0) { topicName, docs, unreadCount in
                // Topic header
                TopicGroupRow(
                  topicName: topicName,
                  documentCount: docs.count,
                  unreadCount: unreadCount,
                  isSelected: selectedTopicOrGroup == topicName,
                  isExpanded: expandedTopics.contains(topicName),
                  onSelect: {
                    selectedTopicOrGroup = topicName
                    if expandedTopics.contains(topicName) {
                      expandedTopics.remove(topicName)
                    } else {
                      expandedTopics.insert(topicName)
                    }
                    if let firstDoc = docs.first {
                      selectedDocument = firstDoc
                      if !firstDoc.isRead {
                        vm.markDocumentRead(firstDoc)
                      }
                    }
                  },
                  onToggleExpand: {
                    if expandedTopics.contains(topicName) {
                      expandedTopics.remove(topicName)
                    } else {
                      expandedTopics.insert(topicName)
                    }
                  }
                )

                // Documents under expanded topics
                if expandedTopics.contains(topicName) {
                  ForEach(docs) { doc in
                    DocumentListRow(
                      doc: doc,
                      isSelected: selectedDocument?.id == doc.id,
                      showTopic: false,
                      onSelect: {
                        selectedDocument = doc
                        selectedTopicOrGroup = topicName
                        if !doc.isRead {
                          vm.markDocumentRead(doc)
                        }
                      }
                    )
                    .padding(.leading, 16)
                  }
                }
              }
            }
          }
        }
        .frame(minWidth: 300, idealWidth: 400, maxWidth: 500)

        // Right: Document detail
        if let doc = selectedDocument {
          DocumentDetailView(
            doc: doc,
            vm: vm,
            userNotes: $userNotes,
            showFollowUpSheet: $showFollowUpSheet
          )
        } else {
          VStack(spacing: 12) {
            Image(systemName: "doc.text")
              .font(.system(size: 64))
              .foregroundStyle(.tertiary)
            Text("Select a document")
              .font(.headline)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .background(Theme.bg)
    .frame(minWidth: 900, idealWidth: 1400, minHeight: 600, idealHeight: 800)
    .sheet(isPresented: $showFollowUpSheet) {
      if let doc = selectedDocument {
        FollowUpRequestSheet(doc: doc, vm: vm, isPresented: $showFollowUpSheet)
      }
    }
    .overlay {
      // Use custom escape key monitor to handle escape even when WKWebView has focus
      DocumentsEscapeKeyMonitor {
        withAnimation(.easeInOut(duration: 0.25)) {
          isPresented = false
        }
      }
      .frame(width: 0, height: 0)
    }
    .onAppear {
      // Initialize expanded topics — expand all by default
      if expandedTopics.isEmpty {
        expandedTopics = Set(topicGroups.map { $0.0 })
      }
      
      // Auto-select first topic and document
      if selectedTopicOrGroup == nil, let firstTopic = topicGroups.first {
        selectedTopicOrGroup = firstTopic.0
        if let firstDoc = firstTopic.1.first {
          selectedDocument = firstDoc
          if !firstDoc.isRead {
            vm.markDocumentRead(firstDoc)
          }
        }
      }
    }
  }
}

// MARK: - Topic Group Row

private struct TopicGroupRow: View {
  let topicName: String
  let documentCount: Int
  let unreadCount: Int
  let isSelected: Bool
  let isExpanded: Bool
  let onSelect: () -> Void
  let onToggleExpand: () -> Void
  
  var body: some View {
    Button {
      onSelect()
    } label: {
      HStack(spacing: 8) {
        Button(action: onToggleExpand) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 12)
        }
        .buttonStyle(.plain)
        
        Image(systemName: topicName == "Reports" ? "doc.text.fill" : "folder.fill")
          .font(.system(size: 14))
          .foregroundStyle(topicName == "Reports" ? .blue : .purple)
        
        Text(topicName)
          .font(.system(size: 13, weight: .semibold))
        
        Spacer()
        
        if unreadCount > 0 {
          Text("\(unreadCount)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple)
            .clipShape(Capsule())
        }
        
        Text("\(documentCount)")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Documents Escape Key Monitor

/// NSEvent-based escape key handler for DocumentsView.
/// Handles escape even when WKWebView (markdown content) has focus.
/// Allows TextField to handle escape first (for clearing search).
private struct DocumentsEscapeKeyMonitor: NSViewRepresentable {
  let onEscape: () -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      // Only handle escape key (keyCode 53)
      if event.keyCode == 53 {
        DispatchQueue.main.async { self.onEscape() }
        return nil
      }
      return event
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {}

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    if let monitor = coordinator.monitor {
      NSEvent.removeMonitor(monitor)
    }
  }

  func makeCoordinator() -> Coordinator { Coordinator() }

  class Coordinator {
    var monitor: Any?
  }
}

// MARK: - Document List Row

private struct DocumentListRow: View {
  let doc: AgentDocument
  let isSelected: Bool
  let showTopic: Bool
  let onSelect: () -> Void

  var body: some View {
    Button {
      onSelect()
    } label: {
      HStack(spacing: 12) {
        // Source icon
        Image(systemName: doc.source.icon)
          .font(.system(size: 16))
          .foregroundStyle(doc.source == .writer ? .blue : .purple)
          .frame(width: 20)

        VStack(alignment: .leading, spacing: 4) {
          // Title
          HStack(spacing: 6) {
            Text(doc.title)
              .font(.system(size: 13, weight: doc.isRead ? .regular : .semibold))
              .lineLimit(2)
              .multilineTextAlignment(.leading)

            if !doc.isRead {
              Circle()
                .fill(.purple)
                .frame(width: 6, height: 6)
            }
            
            if doc.isStarred {
              Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow)
            }
          }
          
          // Summary
          if let summary = doc.summary, !summary.isEmpty {
            Text(summary)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .multilineTextAlignment(.leading)
          }

          // Metadata
          HStack(spacing: 6) {
            // Status badge (if applicable)
            if let status = doc.status {
              Text(status.displayName)
                .font(.system(size: 10))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(statusColor(status).opacity(0.15))
                .foregroundStyle(statusColor(status))
                .cornerRadius(3)
            }

            // Topic (if shown)
            if showTopic, let topic = doc.topic {
              Text(topic)
                .font(.system(size: 10))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .cornerRadius(3)
            }

            Spacer()

            // Date
            Text(doc.date, style: .relative)
              .font(.system(size: 10))
              .foregroundStyle(.tertiary)
          }
        }

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(doc.filename)
  }

  private func statusColor(_ status: DocumentStatus) -> Color {
    switch status {
    case .pending: return .orange
    case .approved: return .green
    case .rejected: return .red
    case .archived: return .gray
    }
  }
}

// MARK: - Document Detail View

private struct DocumentDetailView: View {
  let doc: AgentDocument
  @ObservedObject var vm: AppViewModel
  @Binding var userNotes: String
  @Binding var showFollowUpSheet: Bool
  
  @State private var showCopiedAlert = false

  var body: some View {
    VStack(spacing: 0) {
      // Header with summary
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(doc.title)
            .font(.title2)
            .fontWeight(.bold)

          Spacer()

          // Star/favorite toggle
          Button {
            vm.toggleDocumentStarred(doc)
          } label: {
            Image(systemName: doc.isStarred ? "star.fill" : "star")
              .foregroundStyle(doc.isStarred ? .yellow : .secondary)
          }
          .buttonStyle(.plain)
          .help(doc.isStarred ? "Remove from favorites" : "Add to favorites")

          // Mark read/unread toggle
          Button {
            if doc.isRead {
              vm.markDocumentUnread(doc)
            } else {
              vm.markDocumentRead(doc)
            }
          } label: {
            Image(systemName: doc.isRead ? "eye.slash" : "eye")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
          .help(doc.isRead ? "Mark as unread" : "Mark as read")
        }
        
        // Summary box
        if let summary = doc.summary, !summary.isEmpty {
          HStack(spacing: 8) {
            Image(systemName: "text.alignleft")
              .foregroundStyle(.secondary)
            Text(summary)
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.secondary.opacity(0.08))
          .cornerRadius(8)
        }

        // Metadata
        HStack(spacing: 12) {
          // Source
          Label(doc.source.displayName, systemImage: doc.source.icon)
            .font(.system(size: 12))
            .foregroundStyle(doc.source == .writer ? .blue : .purple)

          // Status
          if let status = doc.status {
            Label(status.displayName, systemImage: "flag.fill")
              .font(.system(size: 12))
              .foregroundStyle(statusColor(status))
          }

          // Topic
          if let topic = doc.topic {
            Label(topic, systemImage: "folder")
              .font(.system(size: 12))
              .foregroundStyle(.purple)
          }

          Spacer()

          // Date
          HStack(spacing: 4) {
            Image(systemName: "calendar")
            Text(doc.date, style: .date)
          }
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        }
        
        // Action buttons
        HStack(spacing: 8) {
          // Convert to Task
          Button {
            convertToTask()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "plus.square")
              Text("Convert to Task")
            }
            .font(.system(size: 12))
          }
          .buttonStyle(.bordered)
          .help("Create a task from this document")
          
          // Request Follow-up
          Button {
            showFollowUpSheet = true
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "arrow.turn.down.right")
              Text("Request Follow-up")
            }
            .font(.system(size: 12))
          }
          .buttonStyle(.bordered)
          .help("Create a research request based on this document")
          
          // Share/Export
          Button {
            copyToClipboard()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.clipboard")
              Text(showCopiedAlert ? "Copied!" : "Copy Content")
            }
            .font(.system(size: 12))
          }
          .buttonStyle(.bordered)
          .help("Copy document content to clipboard")
          
          // Archive
          Button {
            archiveDocument()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "archivebox")
              Text("Archive")
            }
            .font(.system(size: 12))
          }
          .buttonStyle(.bordered)
          .help("Mark as read and hide from view")
        }
      }
      .padding()

      Divider()

      // Content with notes section
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Truncation warning
          if doc.contentIsTruncated {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
              Text("Content truncated for performance. Full document available in repository.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
          }

          // Document content
          NativeMarkdownText(markdown: doc.content)
          
          Divider()
            .padding(.vertical, 8)
          
          // User notes section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Label("Your Notes", systemImage: "note.text")
                .font(.system(size: 14, weight: .semibold))
              Spacer()
              Text("Private annotations")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
            
            TextEditor(text: $userNotes)
              .font(.system(size: 13))
              .frame(minHeight: 100)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            
            if !userNotes.isEmpty {
              Button("Clear Notes") {
                userNotes = ""
              }
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
            }
          }
          .padding(.top, 8)
        }
        .padding()
      }
      
      Divider()
      
      // Footer with file info
      HStack(spacing: 12) {
        Text(doc.filename)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.tertiary)
        
        Spacer()
        
        Text(doc.relativePath)
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
    }
  }
  
  private func convertToTask() {
    // Create task via API
    let taskId = UUID().uuidString
    let title = "Follow up: \(doc.title)"
    let notes = """
    Based on document: \(doc.filename)
    
    \(doc.summary ?? "")
    
    ---
    
    Content preview:
    \(String(doc.content.prefix(500)))
    """
    
    Task {
      do {
        _ = try await vm.api.addTask(
          id: taskId,
          title: title,
          owner: TaskOwner.rafe,
          status: TaskStatus.inbox,
          projectId: doc.projectId,
          workState: WorkState.notStarted,
          reviewState: ReviewState.pending,
          notes: notes
        )
        
        // Show success feedback
        NSSound.beep()
      } catch {
        print("Failed to create task: \(error)")
      }
    }
  }
  
  private func archiveDocument() {
    // Mark as read
    if !doc.isRead {
      vm.markDocumentRead(doc)
    }
    // Note: In a real implementation, you might want to actually move the file
    // to an archived directory. For now, marking as read + hiding read items achieves the goal.
  }
  
  private func copyToClipboard() {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(doc.content, forType: .string)
    
    showCopiedAlert = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      showCopiedAlert = false
    }
  }

  private func statusColor(_ status: DocumentStatus) -> Color {
    switch status {
    case .pending: return .orange
    case .approved: return .green
    case .rejected: return .red
    case .archived: return .gray
    }
  }
}

// MARK: - Follow-up Request Sheet

private struct FollowUpRequestSheet: View {
  let doc: AgentDocument
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var requestPrompt: String = ""
  
  var body: some View {
    VStack(spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Request Follow-up Research")
            .font(.title3)
            .fontWeight(.bold)
          Text("Based on: \(doc.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      
      TextEditor(text: $requestPrompt)
        .font(.system(size: 13))
        .frame(minHeight: 150)
        .padding(8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.escape)
        
        Spacer()
        
        Button("Create Request") {
          createFollowUpRequest()
          isPresented = false
        }
        .keyboardShortcut(.return)
        .disabled(requestPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(20)
    .frame(width: 500, height: 300)
    .onAppear {
      // Pre-fill with suggestion
      requestPrompt = """
      Follow up on: \(doc.title)
      
      Topic: \(doc.topic ?? "research")
      
      Questions to explore:
      - 
      """
    }
  }
  
  private func createFollowUpRequest() {
    // Create research request
    guard let repoURL = vm.repoURL else { return }
    
    let request = ResearchRequest(
      id: UUID().uuidString,
      projectId: doc.topic ?? "research",
      tileId: nil,
      prompt: requestPrompt,
      status: ResearchRequestStatus.open,
      response: nil,
      author: "rafe",
      priority: ResearchPriority.normal,
      deliverables: nil,
      editHistory: nil,
      parentRequestId: nil,
      assignedWorker: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
    
    Task {
      do {
        try await vm.api.saveRequest(request)
        NSSound.beep()
      } catch {
        print("Failed to create research request: \(error)")
      }
    }
  }
}

// MARK: - New Document Sheet

private struct NewDocumentSheet: View {
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var content: String = ""
  @State private var topic: String = ""
  @State private var source: DocumentSource = .writer
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("New Document")
          .font(.title2)
          .fontWeight(.bold)
        
        Spacer()
        
        Button {
          isPresented = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()
      
      Divider()
      
      // Form
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Title
          VStack(alignment: .leading, spacing: 6) {
            Text("Title")
              .font(.subheadline)
              .fontWeight(.medium)
            TextField("Document title", text: $title)
              .textFieldStyle(.roundedBorder)
          }
          
          // Source
          VStack(alignment: .leading, spacing: 6) {
            Text("Source")
              .font(.subheadline)
              .fontWeight(.medium)
            Picker("Source", selection: $source) {
              Text("Writer").tag(DocumentSource.writer)
              Text("Researcher").tag(DocumentSource.researcher)
            }
            .pickerStyle(.segmented)
          }
          
          // Topic (optional, for research)
          if source == .researcher {
            VStack(alignment: .leading, spacing: 6) {
              Text("Topic")
                .font(.subheadline)
                .fontWeight(.medium)
              TextField("Research topic", text: $topic)
                .textFieldStyle(.roundedBorder)
              Text("Optional: categorize this research document")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          
          // Content
          VStack(alignment: .leading, spacing: 6) {
            Text("Content")
              .font(.subheadline)
              .fontWeight(.medium)
            TextEditor(text: $content)
              .font(.system(size: 13, design: .monospaced))
              .frame(minHeight: 300)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            Text("Supports Markdown formatting")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          
          // Error message
          if let error = errorMessage {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
              Text(error)
                .font(.subheadline)
                .foregroundStyle(.red)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
          }
        }
        .padding()
      }
      
      Divider()
      
      // Footer buttons
      HStack(spacing: 12) {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveDocument()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
              .frame(width: 16, height: 16)
          } else {
            Text("Create Document")
          }
        }
        .disabled(title.isEmpty || content.isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 700, height: 650)
    .background(Theme.bg)
  }
  
  private func saveDocument() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        let topicValue = source == .researcher && !topic.isEmpty ? topic : nil
        _ = try await vm.api.createDocument(
          title: title,
          content: content,
          source: source.rawValue,
          topic: topicValue
        )
        
        // Refresh documents list
        await vm.loadAgentDocuments()
        
        // Close sheet
        await MainActor.run {
          isPresented = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isSaving = false
        }
      }
    }
  }
}

// MARK: - Edit Document Sheet

private struct EditDocumentSheet: View {
  let doc: AgentDocument
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title: String
  @State private var content: String
  @State private var topic: String
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  init(doc: AgentDocument, vm: AppViewModel, isPresented: Binding<Bool>) {
    self.doc = doc
    self.vm = vm
    self._isPresented = isPresented
    self._title = State(initialValue: doc.title)
    self._content = State(initialValue: doc.content)
    self._topic = State(initialValue: doc.topic ?? "")
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Edit Document")
          .font(.title2)
          .fontWeight(.bold)
        
        Spacer()
        
        Button {
          isPresented = false
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding()
      
      Divider()
      
      // Form
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Title
          VStack(alignment: .leading, spacing: 6) {
            Text("Title")
              .font(.subheadline)
              .fontWeight(.medium)
            TextField("Document title", text: $title)
              .textFieldStyle(.roundedBorder)
          }
          
          // Topic (if researcher document)
          if doc.source == .researcher {
            VStack(alignment: .leading, spacing: 6) {
              Text("Topic")
                .font(.subheadline)
                .fontWeight(.medium)
              TextField("Research topic", text: $topic)
                .textFieldStyle(.roundedBorder)
              Text("Optional: categorize this research document")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          
          // Content
          VStack(alignment: .leading, spacing: 6) {
            Text("Content")
              .font(.subheadline)
              .fontWeight(.medium)
            TextEditor(text: $content)
              .font(.system(size: 13, design: .monospaced))
              .frame(minHeight: 400)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            Text("Supports Markdown formatting")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          
          // Error message
          if let error = errorMessage {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
              Text(error)
                .font(.subheadline)
                .foregroundStyle(.red)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
          }
        }
        .padding()
      }
      
      Divider()
      
      // Footer buttons
      HStack(spacing: 12) {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveChanges()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
              .frame(width: 16, height: 16)
          } else {
            Text("Save Changes")
          }
        }
        .disabled(title.isEmpty || content.isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 700, height: 650)
    .background(Theme.bg)
  }
  
  private func saveChanges() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        let topicValue = doc.source == .researcher && !topic.isEmpty ? topic : nil
        _ = try await vm.api.updateDocument(
          id: doc.id,
          title: title,
          content: content,
          topic: topicValue
        )
        
        // Refresh documents list
        await vm.loadAgentDocuments()
        
        // Close sheet
        await MainActor.run {
          isPresented = false
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
          isSaving = false
        }
      }
    }
  }
}
