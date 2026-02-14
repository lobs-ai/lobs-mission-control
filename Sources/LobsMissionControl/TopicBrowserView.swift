import SwiftUI

// MARK: - Topic Browser View

struct TopicBrowserView: View {
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var selectedTopic: Topic? = nil
  @State private var topicSearchText: String = ""
  @State private var showCreateTopicSheet: Bool = false
  @State private var expandedSections: Set<String> = ["documents", "requests"]
  @AppStorage("topicsShowRead") private var showReadItems: Bool = true
  
  private var filteredTopics: [Topic] {
    let topics = vm.topics
    
    let q = topicSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !q.isEmpty {
      return topics.filter { topic in
        topic.title.lowercased().contains(q) ||
        (topic.description?.lowercased().contains(q) ?? false)
      }
    }
    
    return topics
  }
  
  private func unreadCount(for topic: Topic) -> Int {
    vm.agentDocuments
      .filter { $0.topicId == topic.id && !$0.isRead }
      .count
  }
  
  private func documentCount(for topic: Topic) -> Int {
    vm.agentDocuments.filter { $0.topicId == topic.id }.count
  }
  
  private func researchRequests(for topic: Topic) -> [ResearchRequest] {
    vm.researchRequests.filter { $0.topicId == topic.id }
  }
  
  private func documents(for topic: Topic) -> [AgentDocument] {
    var docs = vm.agentDocuments.filter { $0.topicId == topic.id }
    
    if !showReadItems {
      docs = docs.filter { !$0.isRead }
    }
    
    return docs.sorted { $0.date > $1.date }
  }
  
  var body: some View {
    HSplitView {
      // Left: Topic Sidebar
      topicSidebar
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
      
      // Right: Content Area
      contentArea
        .frame(minWidth: 500)
    }
    .background(Theme.bg)
    .frame(minWidth: 900, idealWidth: 1400, minHeight: 600, idealHeight: 800)
    .sheet(isPresented: $showCreateTopicSheet) {
      CreateTopicSheet(vm: vm, isPresented: $showCreateTopicSheet)
    }
    .onAppear {
      // Auto-select first topic with unread items
      if selectedTopic == nil {
        if let firstUnread = filteredTopics.first(where: { unreadCount(for: $0) > 0 }) {
          selectedTopic = firstUnread
        } else if let first = filteredTopics.first {
          selectedTopic = first
        }
      }
    }
  }
  
  // MARK: - Topic Sidebar
  
  private var topicSidebar: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "folder.fill")
            .font(.title2)
            .foregroundStyle(.linearGradient(
              colors: [.blue, .purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
          Text("Topics")
            .font(.title3)
            .fontWeight(.bold)
          
          let totalUnread = vm.agentDocuments.filter { !$0.isRead }.count
          if totalUnread > 0 {
            Text("\(totalUnread)")
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
      
      // Search
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .font(.footnote)
        TextField("Search topics...", text: $topicSearchText)
          .textFieldStyle(.plain)
          .font(.callout)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(Theme.subtle)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      
      Divider()
      
      // Topic List
      ScrollView {
        LazyVStack(spacing: 2) {
          if filteredTopics.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
              Text(topicSearchText.isEmpty ? "No topics yet" : "No matches")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
          } else {
            ForEach(filteredTopics) { topic in
              TopicSidebarItem(
                topic: topic,
                documentCount: documentCount(for: topic),
                unreadCount: unreadCount(for: topic),
                isSelected: selectedTopic?.id == topic.id,
                onSelect: {
                  selectedTopic = topic
                }
              )
            }
          }
        }
        .padding(.vertical, 8)
      }
      
      Divider()
      
      // New Topic Button
      Button {
        showCreateTopicSheet = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "plus.circle.fill")
            .font(.footnote)
          Text("New Topic")
            .font(.caption)
            .fontWeight(.medium)
        }
        .foregroundStyle(.blue)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .background(Theme.cardBg)
  }
  
  // MARK: - Content Area
  
  @ViewBuilder
  private var contentArea: some View {
    if let topic = selectedTopic {
      TopicContentView(
        topic: topic,
        documents: documents(for: topic),
        researchRequests: researchRequests(for: topic),
        vm: vm,
        showReadItems: $showReadItems,
        expandedSections: $expandedSections
      )
      .id(topic.id) // Reset view state when topic changes
    } else {
      VStack(spacing: 16) {
        Image(systemName: "folder")
          .font(.system(size: 64))
          .foregroundStyle(.tertiary)
        Text("Select a topic")
          .font(.title3)
          .fontWeight(.medium)
          .foregroundStyle(.secondary)
        Text("Choose a topic from the sidebar to view documents and research")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
          .multilineTextAlignment(.center)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - Topic Sidebar Item

private struct TopicSidebarItem: View {
  let topic: Topic
  let documentCount: Int
  let unreadCount: Int
  let isSelected: Bool
  let onSelect: () -> Void
  
  @State private var isHovering = false
  
  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 10) {
        // Icon
        if let icon = topic.icon, !icon.isEmpty {
          Text(icon)
            .font(.system(size: 18))
        } else {
          Image(systemName: "folder.fill")
            .font(.system(size: 14))
            .foregroundStyle(isSelected ? .blue : .secondary)
        }
        
        VStack(alignment: .leading, spacing: 3) {
          Text(topic.title)
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .lineLimit(2)
          
          if let desc = topic.description, !desc.isEmpty {
            Text(desc)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          if unreadCount > 0 {
            Text("\(unreadCount)")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.blue)
              .clipShape(Capsule())
          }
          
          if documentCount > 0 {
            Text("\(documentCount)")
              .font(.system(size: 11))
              .foregroundStyle(.tertiary)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovering ? Theme.subtle : Color.clear))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
      )
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 8)
    .onHover { h in isHovering = h }
  }
}

// MARK: - Topic Content View

private struct TopicContentView: View {
  let topic: Topic
  let documents: [AgentDocument]
  let researchRequests: [ResearchRequest]
  @ObservedObject var vm: AppViewModel
  @Binding var showReadItems: Bool
  @Binding var expandedSections: Set<String>
  
  @State private var selectedDocument: AgentDocument? = nil
  @State private var showCreateRequestSheet: Bool = false
  @State private var showResearchSheet: Bool = false
  @State private var showCreateTaskSheet: Bool = false
  @State private var showConvertProjectSheet: Bool = false
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      topicHeader
      
      Divider()
      
      // Content Sections
      if selectedDocument == nil {
        topicOverview
      } else if let doc = selectedDocument {
        DocumentDetailView(
          doc: doc,
          vm: vm,
          onBack: { selectedDocument = nil }
        )
      }
    }
  }
  
  private var topicHeader: some View {
    HStack(spacing: 12) {
      if let icon = topic.icon, !icon.isEmpty {
        Text(icon)
          .font(.system(size: 32))
      } else {
        Image(systemName: "folder.fill")
          .font(.title)
          .foregroundStyle(.blue)
      }
      
      VStack(alignment: .leading, spacing: 4) {
        Text(topic.title)
          .font(.title2)
          .fontWeight(.bold)
        
        if let desc = topic.description, !desc.isEmpty {
          Text(desc)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      
      Spacer()
      
      // Action Buttons
      HStack(spacing: 8) {
        Button {
          showResearchSheet = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "magnifyingglass.circle.fill")
            Text("Research This")
          }
          .font(.system(size: 13))
        }
        .buttonStyle(.bordered)
        .help("Create a research request for this topic")
        
        Button {
          showCreateTaskSheet = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "checklist")
            Text("Create Task")
          }
          .font(.system(size: 13))
        }
        .buttonStyle(.bordered)
        .help("Create a task related to this topic")
        
        Button {
          showConvertProjectSheet = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "square.grid.2x2")
            Text("Convert to Project")
          }
          .font(.system(size: 13))
        }
        .buttonStyle(.bordered)
        .help("Create a kanban project for this topic")
      }
      
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
    }
    .padding()
    .sheet(isPresented: $showResearchSheet) {
      ResearchThisSheet(topic: topic, vm: vm, isPresented: $showResearchSheet)
    }
    .sheet(isPresented: $showCreateTaskSheet) {
      CreateTaskFromTopicSheet(topic: topic, vm: vm, isPresented: $showCreateTaskSheet)
    }
    .sheet(isPresented: $showConvertProjectSheet) {
      ConvertToProjectSheet(topic: topic, vm: vm, isPresented: $showConvertProjectSheet)
    }
  }
  
  private var topicOverview: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Research Requests Section
        TopicSection(
          title: "Research Requests",
          icon: "arrow.up.doc",
          count: researchRequests.count,
          color: .orange,
          isExpanded: expandedSections.contains("requests"),
          onToggle: {
            if expandedSections.contains("requests") {
              expandedSections.remove("requests")
            } else {
              expandedSections.insert("requests")
            }
          }
        ) {
          if researchRequests.isEmpty {
            EmptySectionPlaceholder(
              icon: "arrow.up.doc",
              title: "No research requests",
              subtitle: "Create a research request for this topic"
            )
          } else {
            VStack(spacing: 8) {
              ForEach(researchRequests) { request in
                ResearchRequestRow(request: request, vm: vm)
              }
            }
          }
          
          Button {
            showCreateRequestSheet = true
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "plus.circle.fill")
              Text("New Research Request")
            }
            .font(.system(size: 13))
            .foregroundStyle(.blue)
          }
          .buttonStyle(.borderless)
          .padding(.top, 8)
        }
        
        // Documents Section
        TopicSection(
          title: "Documents",
          icon: "doc.text",
          count: documents.count,
          color: .blue,
          isExpanded: expandedSections.contains("documents"),
          onToggle: {
            if expandedSections.contains("documents") {
              expandedSections.remove("documents")
            } else {
              expandedSections.insert("documents")
            }
          }
        ) {
          if documents.isEmpty {
            EmptySectionPlaceholder(
              icon: "doc.text",
              title: showReadItems ? "No documents" : "No unread documents",
              subtitle: showReadItems ? "Documents will appear here" : "All documents have been read"
            )
          } else {
            VStack(spacing: 8) {
              ForEach(documents) { doc in
                TopicDocumentRow(
                  doc: doc,
                  vm: vm,
                  onSelect: { selectedDocument = doc }
                )
              }
            }
          }
        }
      }
      .padding()
    }
    .sheet(isPresented: $showCreateRequestSheet) {
      CreateResearchRequestSheet(
        topicId: topic.id,
        topicTitle: topic.title,
        vm: vm,
        isPresented: $showCreateRequestSheet
      )
    }
  }
}

// MARK: - Topic Section

private struct TopicSection<Content: View>: View {
  let title: String
  let icon: String
  let count: Int
  let color: Color
  let isExpanded: Bool
  let onToggle: () -> Void
  @ViewBuilder let content: Content
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button(action: onToggle) {
        HStack(spacing: 10) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 12)
          
          Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundStyle(color)
          
          Text(title)
            .font(.system(size: 16, weight: .semibold))
          
          Text("(\(count))")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
          
          Spacer()
        }
      }
      .buttonStyle(.plain)
      
      if isExpanded {
        content
          .padding(.leading, 22)
      }
    }
    .padding(16)
    .background(Theme.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Empty Section Placeholder

private struct EmptySectionPlaceholder: View {
  let icon: String
  let title: String
  let subtitle: String
  
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 32))
        .foregroundStyle(.tertiary)
      Text(title)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
      Text(subtitle)
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
}

// MARK: - Research Request Row

private struct ResearchRequestRow: View {
  let request: ResearchRequest
  @ObservedObject var vm: AppViewModel
  
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: statusIcon)
        .font(.system(size: 16))
        .foregroundStyle(statusColor)
        .frame(width: 24)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(request.prompt)
          .font(.system(size: 13, weight: .medium))
          .lineLimit(2)
        
        HStack(spacing: 8) {
          Text(request.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
          
          if let author = request.author {
            Text(author)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
          
          Spacer()
          
          Text(request.createdAt, style: .relative)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
      
      Spacer()
    }
    .padding(12)
    .background(Theme.subtle)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
  
  private var statusIcon: String {
    switch request.status {
    case .open: return "circle"
    case .inProgress: return "arrow.clockwise"
    case .completed, .done: return "checkmark.circle.fill"
    case .blocked: return "xmark.circle"
    }
  }
  
  private var statusColor: Color {
    switch request.status {
    case .open: return .orange
    case .inProgress: return .blue
    case .completed, .done: return .green
    case .blocked: return .gray
    }
  }
}

// MARK: - Topic Document Row

private struct TopicDocumentRow: View {
  let doc: AgentDocument
  @ObservedObject var vm: AppViewModel
  let onSelect: () -> Void
  
  var body: some View {
    Button(action: {
      onSelect()
      if !doc.isRead {
        vm.markDocumentRead(doc)
      }
    }) {
      HStack(spacing: 12) {
        Image(systemName: doc.source.icon)
          .font(.system(size: 16))
          .foregroundStyle(doc.source == .writer ? .blue : .purple)
          .frame(width: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(doc.title)
              .font(.system(size: 13, weight: doc.isRead ? .regular : .semibold))
              .lineLimit(2)
            
            if !doc.isRead {
              Circle()
                .fill(.blue)
                .frame(width: 6, height: 6)
            }
          }
          
          if let summary = doc.summary, !summary.isEmpty {
            Text(summary)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          
          HStack(spacing: 6) {
            if let status = doc.status {
              Text(status.displayName)
                .font(.system(size: 10))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(statusColor(status).opacity(0.15))
                .foregroundStyle(statusColor(status))
                .cornerRadius(3)
            }
            
            Spacer()
            
            Text(doc.date, style: .relative)
              .font(.system(size: 10))
              .foregroundStyle(.tertiary)
          }
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }
      .padding(12)
      .background(Theme.subtle)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
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
  let onBack: () -> Void
  
  @State private var showCopiedAlert = false
  @State private var showCreateTaskSheet = false
  @State private var showFollowUpResearchSheet = false
  @State private var userNotes: String = ""
  @State private var isReviewed: Bool = false
  
  var body: some View {
    VStack(spacing: 0) {
      // Back button + title
      HStack {
        Button(action: onBack) {
          HStack(spacing: 4) {
            Image(systemName: "chevron.left")
            Text("Back")
          }
          .font(.system(size: 13))
        }
        .buttonStyle(.borderless)
        
        Spacer()
        
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
      .padding()
      
      Divider()
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          // Title
          Text(doc.title)
            .font(.title2)
            .fontWeight(.bold)
          
          // Summary
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
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
              Label(doc.source.displayName, systemImage: doc.source.icon)
                .font(.system(size: 12))
                .foregroundStyle(doc.source == .writer ? .blue : .purple)
              
              if let status = doc.status {
                Label(status.displayName, systemImage: "flag.fill")
                  .font(.system(size: 12))
                  .foregroundStyle(statusColor(status))
              }
              
              Spacer()
              
              HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(doc.date, style: .date)
              }
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
            }
            
            // Topic if available
            if let topicId = doc.topicId, let topic = vm.topics.first(where: { $0.id == topicId }) {
              HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                  .font(.system(size: 11))
                if let icon = topic.icon, !icon.isEmpty {
                  Text(icon)
                    .font(.system(size: 11))
                }
                Text("Topic: \(topic.title)")
                  .font(.system(size: 12))
              }
              .foregroundStyle(.secondary)
            }
          }
          
          // Action buttons
          VStack(alignment: .leading, spacing: 8) {
            Text("Actions")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
              Button {
                showCreateTaskSheet = true
              } label: {
                HStack(spacing: 4) {
                  Image(systemName: "checklist")
                  Text("Create Task")
                }
                .font(.system(size: 12))
              }
              .buttonStyle(.bordered)
              
              Button {
                showFollowUpResearchSheet = true
              } label: {
                HStack(spacing: 4) {
                  Image(systemName: "arrow.up.doc")
                  Text("Follow-up Research")
                }
                .font(.system(size: 12))
              }
              .buttonStyle(.bordered)
              
              Button {
                isReviewed.toggle()
              } label: {
                HStack(spacing: 4) {
                  Image(systemName: isReviewed ? "checkmark.seal.fill" : "checkmark.seal")
                  Text(isReviewed ? "Reviewed" : "Mark Reviewed")
                }
                .font(.system(size: 12))
              }
              .buttonStyle(.bordered)
              .tint(isReviewed ? .green : .blue)
              
              Button {
                copyToClipboard()
              } label: {
                HStack(spacing: 4) {
                  Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.clipboard")
                  Text(showCopiedAlert ? "Copied!" : "Copy")
                }
                .font(.system(size: 12))
              }
              .buttonStyle(.bordered)
            }
          }
          
          Divider()
          
          // Inline Notes/Comments
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Your Notes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
              
              Spacer()
              
              if !userNotes.isEmpty {
                Text("\(userNotes.count) characters")
                  .font(.system(size: 11))
                  .foregroundStyle(.tertiary)
              }
            }
            
            TextEditor(text: $userNotes)
              .font(.system(size: 13))
              .frame(height: 80)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            
            if !userNotes.isEmpty {
              Text("Notes are saved locally and won't be synced to the server")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
          
          Divider()
          
          // Content
          if doc.contentIsTruncated {
            HStack(spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
              Text("Content truncated. Full document available in repository.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
          }
          
          NativeMarkdownText(markdown: doc.content)
        }
        .padding()
      }
    }
    .sheet(isPresented: $showCreateTaskSheet) {
      CreateTaskFromDocumentSheet(doc: doc, vm: vm, isPresented: $showCreateTaskSheet)
    }
    .sheet(isPresented: $showFollowUpResearchSheet) {
      FollowUpResearchSheet(doc: doc, vm: vm, isPresented: $showFollowUpResearchSheet)
    }
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

// MARK: - Create Topic Sheet

private struct CreateTopicSheet: View {
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var description: String = ""
  @State private var icon: String = ""
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("New Topic")
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
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Title")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("Topic title", text: $title)
            .textFieldStyle(.roundedBorder)
        }
        
        VStack(alignment: .leading, spacing: 6) {
          Text("Icon (emoji)")
            .font(.subheadline)
            .fontWeight(.medium)
          TextField("📚", text: $icon)
            .textFieldStyle(.roundedBorder)
          Text("Optional: single emoji for visual identification")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        VStack(alignment: .leading, spacing: 6) {
          Text("Description")
            .font(.subheadline)
            .fontWeight(.medium)
          TextEditor(text: $description)
            .font(.system(size: 13))
            .frame(height: 100)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        
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
      
      Divider()
      
      // Footer
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveTopic()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            Text("Create Topic")
          }
        }
        .disabled(title.isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 500, height: 450)
    .background(Theme.bg)
  }
  
  private func saveTopic() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        _ = try await vm.api.createTopic(
          title: title,
          description: description.isEmpty ? nil : description,
          icon: icon.isEmpty ? nil : icon
        )
        
        await vm.loadTopics()
        
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

// MARK: - Create Research Request Sheet

private struct CreateResearchRequestSheet: View {
  let topicId: String
  let topicTitle: String
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var prompt: String = ""
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("New Research Request")
            .font(.title3)
            .fontWeight(.bold)
          Text("Topic: \(topicTitle)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
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
      
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Research Question")
            .font(.subheadline)
            .fontWeight(.medium)
          TextEditor(text: $prompt)
            .font(.system(size: 13))
            .frame(height: 150)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        
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
      
      Divider()
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveRequest()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            Text("Create Request")
          }
        }
        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 500, height: 350)
    .background(Theme.bg)
  }
  
  private func saveRequest() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        _ = try await vm.api.createResearchRequestForTopic(
          topicId: topicId,
          prompt: prompt
        )
        
        await vm.loadResearchRequests()
        
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

// MARK: - Research This Sheet

private struct ResearchThisSheet: View {
  let topic: Topic
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var prompt: String = ""
  @State private var comments: String = ""
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Research This Topic")
            .font(.title3)
            .fontWeight(.bold)
          Text("Topic: \(topic.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
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
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Research Question")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("What would you like to research about this topic?")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $prompt)
              .font(.system(size: 13))
              .frame(height: 120)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Comments / Context (Optional)")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("Add any additional notes or context for the research")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $comments)
              .font(.system(size: 13))
              .frame(height: 80)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
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
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveRequest()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            HStack(spacing: 4) {
              Image(systemName: "magnifyingglass.circle.fill")
              Text("Create Research Request")
            }
          }
        }
        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 550, height: 450)
    .background(Theme.bg)
  }
  
  private func saveRequest() {
    isSaving = true
    errorMessage = nil
    
    // Combine prompt with comments
    var fullPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    if !comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      fullPrompt += "\n\nAdditional Context:\n" + comments
    }
    
    Task {
      do {
        _ = try await vm.api.createResearchRequestForTopic(
          topicId: topic.id,
          prompt: fullPrompt
        )
        
        await vm.loadResearchRequests()
        
        await MainActor.run {
          vm.flashSuccess("Research request created for \(topic.title)")
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

// MARK: - Create Task From Topic Sheet

private struct CreateTaskFromTopicSheet: View {
  let topic: Topic
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var notes: String = ""
  @State private var selectedProjectId: String?
  @State private var owner: TaskOwner = .lobs
  @State private var assignedAgent: String = "programmer"
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  private var availableAgents: [(String, String, String)] {
    [
      ("programmer", "🛠️", "Code implementation, bug fixes"),
      ("researcher", "🔬", "Research and investigation"),
      ("reviewer", "🔍", "Code review and feedback"),
      ("writer", "✍️", "Documentation and writing"),
      ("architect", "🏗️", "System design and architecture")
    ]
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Create Task")
            .font(.title3)
            .fontWeight(.bold)
          Text("Topic: \(topic.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
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
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Task Title")
              .font(.subheadline)
              .fontWeight(.medium)
            TextField("Enter task title", text: $title)
              .textFieldStyle(.roundedBorder)
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("Pre-filled with topic context. Edit as needed.")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $notes)
              .font(.system(size: 13))
              .frame(height: 120)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Project (Optional)")
              .font(.subheadline)
              .fontWeight(.medium)
            Picker("Select project", selection: $selectedProjectId) {
              Text("No Project").tag(nil as String?)
              ForEach(vm.projects) { project in
                Text(project.title).tag(project.id as String?)
              }
            }
            .pickerStyle(.menu)
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Owner")
              .font(.subheadline)
              .fontWeight(.medium)
            Picker("Task owner", selection: $owner) {
              Text("Me (Rafe)").tag(TaskOwner.rafe)
              Text("AI (Lobs)").tag(TaskOwner.lobs)
            }
            .pickerStyle(.segmented)
          }
          
          if owner == .lobs {
            VStack(alignment: .leading, spacing: 6) {
              Text("Agent")
                .font(.subheadline)
                .fontWeight(.medium)
              
              Menu {
                ForEach(availableAgents, id: \.0) { agent in
                  Button {
                    assignedAgent = agent.0
                  } label: {
                    HStack(spacing: 6) {
                      Text(agent.1)  // emoji
                      VStack(alignment: .leading, spacing: 2) {
                        Text(agent.0.capitalized)
                          .font(.body)
                        Text(agent.2)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                    }
                  }
                }
              } label: {
                HStack(spacing: 8) {
                  if let selected = availableAgents.first(where: { $0.0 == assignedAgent }) {
                    Text(selected.1)  // emoji
                    Text(selected.0.capitalized)
                      .font(.body)
                  } else {
                    Text("Select agent")
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
              }
              .buttonStyle(.plain)
            }
          }
          
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
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveTask()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            HStack(spacing: 4) {
              Image(systemName: "checklist")
              Text("Create Task")
            }
          }
        }
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 550, height: 600)
    .background(Theme.bg)
    .onAppear {
      initializeDefaults()
    }
  }
  
  private func initializeDefaults() {
    // Pre-fill notes with topic context
    var contextNotes = "Related to topic: \(topic.title)"
    if let desc = topic.description, !desc.isEmpty {
      contextNotes += "\n\n\(desc)"
    }
    notes = contextNotes
    
    // Pre-select linked project if available
    if let linkedProjectId = topic.linkedProjectId {
      selectedProjectId = linkedProjectId
    }
  }
  
  private func saveTask() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        _ = try await vm.api.addTask(
          title: title,
          owner: owner,
          status: .inbox,
          projectId: selectedProjectId,
          notes: notes,
          agent: owner == .lobs ? assignedAgent : nil
        )
        
        await MainActor.run {
          vm.flashSuccess("Task created: \(title)")
          vm.silentReload()
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

// MARK: - Convert to Project Sheet

private struct ConvertToProjectSheet: View {
  let topic: Topic
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var notes: String = ""
  @State private var projectType: ProjectType = .kanban
  @State private var linkToTopic: Bool = true
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Convert to Project")
            .font(.title3)
            .fontWeight(.bold)
          Text("Create a project linked to: \(topic.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
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
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Project Title")
              .font(.subheadline)
              .fontWeight(.medium)
            TextField("Enter project title", text: $title)
              .textFieldStyle(.roundedBorder)
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Project Type")
              .font(.subheadline)
              .fontWeight(.medium)
            Picker("Project type", selection: $projectType) {
              Text("Kanban Board").tag(ProjectType.kanban)
              Text("Research").tag(ProjectType.research)
              Text("Tracker").tag(ProjectType.tracker)
            }
            .pickerStyle(.menu)
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Description / Notes")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("Pre-filled with topic context. Edit as needed.")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $notes)
              .font(.system(size: 13))
              .frame(height: 120)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
          Toggle(isOn: $linkToTopic) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Link project to topic")
                .font(.subheadline)
                .fontWeight(.medium)
              Text("Associate this project with the \(topic.title) topic")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .toggleStyle(.switch)
          
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
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveProject()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            HStack(spacing: 4) {
              Image(systemName: "square.grid.2x2")
              Text("Create Project")
            }
          }
        }
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 550, height: 500)
    .background(Theme.bg)
    .onAppear {
      initializeDefaults()
    }
  }
  
  private func initializeDefaults() {
    // Pre-fill title from topic
    title = topic.title
    
    // Pre-fill notes with topic context
    var contextNotes = "Project for: \(topic.title)"
    if let desc = topic.description, !desc.isEmpty {
      contextNotes += "\n\n\(desc)"
    }
    notes = contextNotes
  }
  
  private func saveProject() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        let projectId = "proj-\(UUID().uuidString.lowercased())"
        
        _ = try await vm.api.createProject(
          id: projectId,
          title: title,
          type: projectType,
          notes: notes
        )
        
        // Link project to topic if requested
        if linkToTopic {
          // TODO: API call to link project to topic (needs backend support)
          // For now, the topic.linkedProjectId is set on the topic side
        }
        
        await MainActor.run {
          vm.flashSuccess("Project created: \(title)")
          vm.silentReload()
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

// MARK: - Create Task From Document Sheet

private struct CreateTaskFromDocumentSheet: View {
  let doc: AgentDocument
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var notes: String = ""
  @State private var selectedProjectId: String?
  @State private var owner: TaskOwner = .lobs
  @State private var assignedAgent: String = "programmer"
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  private var availableAgents: [(String, String, String)] {
    [
      ("programmer", "🛠️", "Code implementation, bug fixes"),
      ("researcher", "🔬", "Research and investigation"),
      ("reviewer", "🔍", "Code review and feedback"),
      ("writer", "✍️", "Documentation and writing"),
      ("architect", "🏗️", "System design and architecture")
    ]
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Create Task from Document")
            .font(.title3)
            .fontWeight(.bold)
          Text("Source: \(doc.title)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        
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
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Task Title")
              .font(.subheadline)
              .fontWeight(.medium)
            TextField("Enter task title", text: $title)
              .textFieldStyle(.roundedBorder)
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("Pre-filled with document context. Edit as needed.")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $notes)
              .font(.system(size: 13))
              .frame(height: 150)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Project (Optional)")
              .font(.subheadline)
              .fontWeight(.medium)
            Picker("Select project", selection: $selectedProjectId) {
              Text("No Project").tag(nil as String?)
              ForEach(vm.projects) { project in
                Text(project.title).tag(project.id as String?)
              }
            }
            .pickerStyle(.menu)
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Owner")
              .font(.subheadline)
              .fontWeight(.medium)
            Picker("Task owner", selection: $owner) {
              Text("Me (Rafe)").tag(TaskOwner.rafe)
              Text("AI (Lobs)").tag(TaskOwner.lobs)
            }
            .pickerStyle(.segmented)
          }
          
          if owner == .lobs {
            VStack(alignment: .leading, spacing: 6) {
              Text("Agent")
                .font(.subheadline)
                .fontWeight(.medium)
              
              Menu {
                ForEach(availableAgents, id: \.0) { agent in
                  Button {
                    assignedAgent = agent.0
                  } label: {
                    HStack(spacing: 6) {
                      Text(agent.1)  // emoji
                      VStack(alignment: .leading, spacing: 2) {
                        Text(agent.0.capitalized)
                          .font(.body)
                        Text(agent.2)
                          .font(.caption)
                          .foregroundStyle(.secondary)
                      }
                    }
                  }
                }
              } label: {
                HStack(spacing: 8) {
                  if let selected = availableAgents.first(where: { $0.0 == assignedAgent }) {
                    Text(selected.1)  // emoji
                    Text(selected.0.capitalized)
                      .font(.body)
                  } else {
                    Text("Select agent")
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
              }
              .buttonStyle(.plain)
            }
          }
          
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
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveTask()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            HStack(spacing: 4) {
              Image(systemName: "checklist")
              Text("Create Task")
            }
          }
        }
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 550, height: 650)
    .background(Theme.bg)
    .onAppear {
      initializeDefaults()
    }
  }
  
  private func initializeDefaults() {
    // Pre-fill title from document
    title = "Task from: \(doc.title)"
    
    // Pre-fill notes with document context
    var contextNotes = "**Source Document:** \(doc.title)\n"
    contextNotes += "**Date:** \(doc.date.formatted(date: .abbreviated, time: .omitted))\n"
    contextNotes += "**Agent:** \(doc.source.displayName)\n\n"
    
    if let summary = doc.summary, !summary.isEmpty {
      contextNotes += "**Summary:**\n\(summary)\n\n"
    }
    
    contextNotes += "**Document ID:** \(doc.id)\n\n"
    contextNotes += "---\n\n"
    contextNotes += "*Add task details here*"
    
    notes = contextNotes
    
    // Pre-select project if document has one
    if let projectId = doc.projectId {
      selectedProjectId = projectId
    }
  }
  
  private func saveTask() {
    isSaving = true
    errorMessage = nil
    
    Task {
      do {
        _ = try await vm.api.addTask(
          title: title,
          owner: owner,
          status: .inbox,
          projectId: selectedProjectId,
          notes: notes,
          agent: owner == .lobs ? assignedAgent : nil
        )
        
        await MainActor.run {
          vm.flashSuccess("Task created: \(title)")
          vm.silentReload()
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

// MARK: - Follow-up Research Sheet

private struct FollowUpResearchSheet: View {
  let doc: AgentDocument
  @ObservedObject var vm: AppViewModel
  @Binding var isPresented: Bool
  
  @State private var prompt: String = ""
  @State private var comments: String = ""
  @State private var isSaving: Bool = false
  @State private var errorMessage: String?
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
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
      
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Research Question")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("What follow-up research is needed based on this document?")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $prompt)
              .font(.system(size: 13))
              .frame(height: 120)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
          VStack(alignment: .leading, spacing: 6) {
            Text("Additional Context (Optional)")
              .font(.subheadline)
              .fontWeight(.medium)
            Text("Add any specific focus areas or constraints")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextEditor(text: $comments)
              .font(.system(size: 13))
              .frame(height: 80)
              .padding(8)
              .background(Color(NSColor.textBackgroundColor))
              .cornerRadius(6)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
          }
          
          // Document context preview
          VStack(alignment: .leading, spacing: 6) {
            Text("Document Context (Auto-included)")
              .font(.subheadline)
              .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text("Source:")
                  .fontWeight(.medium)
                Text(doc.title)
              }
              .font(.system(size: 12))
              
              HStack {
                Text("Agent:")
                  .fontWeight(.medium)
                Text(doc.source.displayName)
              }
              .font(.system(size: 12))
              
              HStack {
                Text("Date:")
                  .fontWeight(.medium)
                Text(doc.date, style: .date)
              }
              .font(.system(size: 12))
              
              if let summary = doc.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                  Text("Summary:")
                    .fontWeight(.medium)
                  Text(summary)
                    .foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
              }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
          }
          
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
      
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button {
          saveRequest()
        } label: {
          if isSaving {
            ProgressView()
              .scaleEffect(0.7)
          } else {
            HStack(spacing: 4) {
              Image(systemName: "arrow.up.doc")
              Text("Create Research Request")
            }
          }
        }
        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        .keyboardShortcut(.defaultAction)
      }
      .padding()
    }
    .frame(width: 600, height: 650)
    .background(Theme.bg)
  }
  
  private func saveRequest() {
    isSaving = true
    errorMessage = nil
    
    // Build full prompt with document context
    var fullPrompt = "**Follow-up Research Request**\n\n"
    fullPrompt += "**Source Document:** \(doc.title)\n"
    fullPrompt += "**Source Agent:** \(doc.source.displayName)\n"
    fullPrompt += "**Document Date:** \(doc.date.formatted(date: .abbreviated, time: .omitted))\n"
    
    if let summary = doc.summary, !summary.isEmpty {
      fullPrompt += "**Document Summary:** \(summary)\n"
    }
    
    fullPrompt += "\n---\n\n"
    fullPrompt += "**Research Question:**\n\(prompt.trimmingCharacters(in: .whitespacesAndNewlines))\n"
    
    if !comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      fullPrompt += "\n**Additional Context:**\n\(comments)\n"
    }
    
    fullPrompt += "\n---\n\n"
    fullPrompt += "**Document ID:** \(doc.id)"
    
    Task {
      do {
        // Try to create research request linked to topic if available
        if let topicId = doc.topicId {
          _ = try await vm.api.createResearchRequestForTopic(
            topicId: topicId,
            prompt: fullPrompt
          )
        } else if let projectId = doc.projectId {
          // Fallback to project-based request
          let request = ResearchRequest(
            id: UUID().uuidString,
            projectId: projectId,
            topicId: nil,
            tileId: nil,
            prompt: fullPrompt,
            status: .open,
            response: nil,
            author: "rafe",
            priority: .normal,
            deliverables: nil,
            editHistory: nil,
            parentRequestId: nil,
            assignedWorker: nil,
            createdAt: Date(),
            updatedAt: Date()
          )
          
          try await vm.api.addResearchRequest(projectId: projectId, request: request)
        } else {
          throw NSError(domain: "DocumentDetailView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No topic or project associated with this document"])
        }
        
        await vm.loadResearchRequests()
        
        await MainActor.run {
          vm.flashSuccess("Follow-up research request created")
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
