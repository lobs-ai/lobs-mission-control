import SwiftUI

// MARK: - Theme

private typealias DocTheme = Theme

// MARK: - Research Doc View (Simplified)

struct ResearchDocView: View {
  @ObservedObject var vm: AppViewModel
  
  @State private var showAddRequest = false
  @State private var isEditing = false
  @State private var editContent: String = ""
  @State private var saveTimer: Timer? = nil
  @State private var searchText: String = ""
  @State private var selectedItem: ResearchItem? = nil
  
  // Grouped research items
  private var researchItems: [ResearchItem] {
    var items: [ResearchItem] = []
    
    // Main document
    items.append(ResearchItem(
      id: "main-doc",
      type: .document,
      title: "Research Document",
      preview: String(vm.researchDocContent.prefix(150)),
      content: vm.researchDocContent,
      modifiedAt: Date()
    ))
    
    // Deliverables (findings)
    for deliverable in vm.researchDeliverables {
      items.append(ResearchItem(
        id: deliverable.id,
        type: .finding,
        title: deliverable.title,
        preview: String(deliverable.content.prefix(150)),
        content: deliverable.content,
        modifiedAt: deliverable.modifiedAt
      ))
    }
    
    // Research tiles as notes/links
    for tile in vm.researchTiles {
      let type: ResearchItemType = tile.type == .link ? .link : .note
      let content = tile.content ?? tile.summary ?? ""
      items.append(ResearchItem(
        id: tile.id,
        type: type,
        title: tile.title,
        preview: String(content.prefix(150)),
        content: content,
        url: tile.url,
        modifiedAt: tile.updatedAt
      ))
    }
    
    return items.sorted { $0.modifiedAt > $1.modifiedAt }
  }
  
  // Filter items by search
  private var filteredItems: [ResearchItem] {
    if searchText.isEmpty {
      return researchItems
    }
    return researchItems.filter { item in
      item.title.localizedCaseInsensitiveContains(searchText) ||
      item.preview.localizedCaseInsensitiveContains(searchText)
    }
  }
  
  // Group items by type
  private var groupedItems: [(String, [ResearchItem])] {
    let findings = filteredItems.filter { $0.type == .finding }
    let notes = filteredItems.filter { $0.type == .note }
    let links = filteredItems.filter { $0.type == .link }
    let docs = filteredItems.filter { $0.type == .document }
    
    var groups: [(String, [ResearchItem])] = []
    if !docs.isEmpty { groups.append(("Documents", docs)) }
    if !findings.isEmpty { groups.append(("Findings", findings)) }
    if !notes.isEmpty { groups.append(("Notes", notes)) }
    if !links.isEmpty { groups.append(("Links", links)) }
    
    return groups
  }
  
  var body: some View {
    HSplitView {
      // Left panel: Item list
      leftPanel
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400)
      
      // Right panel: Selected item content
      rightPanel
        .frame(minWidth: 500)
    }
    .onAppear {
      editContent = vm.researchDocContent
      if selectedItem == nil && !researchItems.isEmpty {
        selectedItem = researchItems.first
      }
    }
    .onChange(of: vm.researchDocContent) { newValue in
      if !isEditing {
        editContent = newValue
      }
    }
    .sheet(isPresented: $showAddRequest) {
      AskLobsResearchSheet(vm: vm, sectionContext: nil)
    }
  }
  
  // MARK: - Left Panel
  
  private var leftPanel: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Image(systemName: "doc.text.magnifyingglass")
          .foregroundStyle(.orange)
        Text("Research")
          .font(.headline)
        
        Spacer()
        
        Button(action: { showAddRequest = true }) {
          Image(systemName: "plus.circle.fill")
            .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
        .help("Ask Lobs to research something")
      }
      .padding()
      
      Divider()
      
      // Search
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .font(.footnote)
        TextField("Search…", text: $searchText)
          .textFieldStyle(.plain)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .padding(.horizontal, 12)
      .padding(.top, 12)
      
      // Item list
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          ForEach(groupedItems, id: \.0) { groupName, items in
            VStack(alignment: .leading, spacing: 8) {
              // Group header
              Text(groupName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
              
              // Items in group
              ForEach(items) { item in
                ItemRow(
                  item: item,
                  isSelected: selectedItem?.id == item.id,
                  onSelect: {
                    selectedItem = item
                    editContent = item.content
                    isEditing = false
                  }
                )
              }
            }
          }
        }
        .padding(.vertical, 12)
      }
      .background(DocTheme.boardBg)
    }
  }
  
  // MARK: - Right Panel
  
  private var rightPanel: some View {
    VStack(spacing: 0) {
      if let item = selectedItem {
        // Toolbar
        HStack {
          Text(item.title)
            .font(.title3)
            .fontWeight(.semibold)
          
          Spacer()
          
          // Edit/Preview toggle for editable items
          if item.type == .document || item.type == .finding {
            Picker("", selection: $isEditing) {
              Text("Preview").tag(false)
              Text("Edit").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)
          }
          
          // Word count
          let wordCount = editContent.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
          if wordCount > 0 {
            Text("\(wordCount) words")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
        .padding()
        
        Divider()
        
        // Content
        if isEditing {
          // Editor
          SpellCheckingTextEditor(text: $editContent)
            .padding()
            .onChange(of: editContent) { _ in
              scheduleSave()
            }
        } else {
          // Preview
          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              if item.type == .link, let url = item.url {
                // Link preview
                HStack(spacing: 8) {
                  Image(systemName: "link.circle.fill")
                    .foregroundStyle(.blue)
                  Link(url, destination: URL(string: url)!)
                    .font(.subheadline)
                }
                .padding(.bottom, 12)
              }
              
              // Markdown content
              MarkdownPreviewView(markdown: editContent)
                .textSelection(.enabled)
            }
            .padding()
          }
        }
      } else {
        // Empty state
        VStack(spacing: 12) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
          Text("Select an item to view")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }
  
  // MARK: - Save
  
  private func scheduleSave() {
    saveTimer?.invalidate()
    saveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak vm] _ in
      guard let vm = vm, let item = selectedItem else { return }
      
      Task { @MainActor in
        if item.type == .document {
          vm.saveResearchDocContent(editContent)
        }
        // Note: deliverable editing would need API support
      }
    }
  }
}

// MARK: - Research Item Model

private struct ResearchItem: Identifiable, Hashable {
  let id: String
  let type: ResearchItemType
  let title: String
  let preview: String
  let content: String
  var url: String? = nil
  let modifiedAt: Date
}

private enum ResearchItemType {
  case document
  case finding
  case note
  case link
}

// MARK: - Item Row

private struct ItemRow: View {
  let item: ResearchItem
  let isSelected: Bool
  let onSelect: () -> Void
  
  var body: some View {
    Button(action: onSelect) {
      HStack(alignment: .top, spacing: 12) {
        // Icon
        Image(systemName: iconName)
          .font(.body)
          .foregroundStyle(iconColor)
          .frame(width: 20)
        
        VStack(alignment: .leading, spacing: 4) {
          // Title
          Text(item.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(2)
            .foregroundStyle(.primary)
          
          // Preview
          if !item.preview.isEmpty {
            Text(item.preview)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
          
          // Date
          Text(formatDate(item.modifiedAt))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        
        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }
  
  private var iconName: String {
    switch item.type {
    case .document: return "doc.text"
    case .finding: return "lightbulb"
    case .note: return "note.text"
    case .link: return "link"
    }
  }
  
  private var iconColor: Color {
    switch item.type {
    case .document: return .orange
    case .finding: return .yellow
    case .note: return .purple
    case .link: return .blue
    }
  }
  
  private func formatDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

// MARK: - Markdown Preview

private struct MarkdownPreviewView: View {
  let markdown: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
        renderLine(line)
      }
    }
  }
  
  private var lines: [String] {
    markdown.components(separatedBy: .newlines)
  }
  
  @ViewBuilder
  private func renderLine(_ line: String) -> some View {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    
    if trimmed.hasPrefix("### ") {
      Text(String(trimmed.dropFirst(4)))
        .font(.title3)
        .fontWeight(.semibold)
        .padding(.top, 8)
    } else if trimmed.hasPrefix("## ") {
      Text(String(trimmed.dropFirst(3)))
        .font(.title2)
        .fontWeight(.bold)
        .padding(.top, 12)
    } else if trimmed.hasPrefix("# ") {
      Text(String(trimmed.dropFirst(2)))
        .font(.title)
        .fontWeight(.bold)
        .padding(.top, 16)
    } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
      HStack(alignment: .top, spacing: 8) {
        Text("•")
          .foregroundStyle(.secondary)
        Text(String(trimmed.dropFirst(2)))
      }
      .padding(.leading, 12)
    } else if !trimmed.isEmpty {
      Text(trimmed)
        .fixedSize(horizontal: false, vertical: true)
    } else {
      Spacer().frame(height: 8)
    }
  }
}

// MARK: - Ask Lobs Research Sheet

private struct AskLobsResearchSheet: View {
  @ObservedObject var vm: AppViewModel
  let sectionContext: String?
  
  @Environment(\.dismiss) private var dismiss
  @State private var prompt: String = ""
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Ask Lobs to Research")
        .font(.title2)
        .fontWeight(.bold)
      
      if let context = sectionContext {
        Text("Context: \(context)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      
      TextEditor(text: $prompt)
        .font(.body)
        .frame(height: 120)
        .border(Color.secondary.opacity(0.2))
      
      HStack {
        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)
        
        Spacer()
        
        Button("Submit") {
          vm.addRequest(prompt: prompt)
          dismiss()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding()
    .frame(width: 500, height: 250)
  }
}
