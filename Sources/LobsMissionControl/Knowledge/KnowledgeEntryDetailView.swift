import SwiftUI

struct KnowledgeEntryDetailView: View {
    let entry: KnowledgeEntry
    @ObservedObject var service: KnowledgeService
    let onBack: () -> Void
    let onRequestResearch: () -> Void
    
    @State private var content: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showCopied = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                // Back button
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button {
                        onRequestResearch()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass.circle.fill")
                            Text("Research This")
                        }
                        .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered)
                    
                    if let content = content {
                        Button {
                            copyToClipboard(content)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.clipboard")
                                Text(showCopied ? "Copied!" : "Copy")
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title and metadata
                    VStack(alignment: .leading, spacing: 12) {
                        // Type badge + collection indicator
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: entry.icon)
                                    .font(.system(size: 12))
                                Text(entry.type.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(typeColor(entry.type).opacity(0.15))
                            .foregroundStyle(typeColor(entry.type))
                            .clipShape(Capsule())
                            
                            if entry.isCollection {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 12))
                                    Text("Collection")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                            }
                        }
                        
                        // Title
                        Text(entry.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Summary
                        if let summary = entry.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // Metadata grid
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 20) {
                                // Path
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Path")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                    Text(entry.path)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Created
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Created")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                    Text(entry.fileCreatedAt, style: .date)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Updated
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Updated")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                    Text(entry.fileUpdatedAt, style: .relative)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            // Author and tags row
                            HStack(spacing: 20) {
                                if let author = entry.createdBy {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Author")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 10))
                                            Text(author)
                                        }
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                
                                if !entry.tags.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Tags")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)
                                        HStack(spacing: 6) {
                                            ForEach(entry.tags, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.system(size: 11))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.1))
                                                    .foregroundStyle(.secondary)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Divider()
                    
                    // Content
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Loading content...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.red)
                            Text("Failed to load content")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await loadContent()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let content = content {
                        SelfSizingMarkdownView(markdown: content, minHeight: 100)
                    }
                }
                .padding()
            }
        }
        .task {
            await loadContent()
        }
    }
    
    private func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let loadedContent = try await service.loadContent(path: entry.path)
            await MainActor.run {
                content = loadedContent
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        showCopied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await MainActor.run {
                showCopied = false
            }
        }
    }
    
    private func typeColor(_ type: KnowledgeType) -> Color {
        switch type {
        case .research: return .blue
        case .doc: return .green
        case .design: return .purple
        case .decision: return .orange
        }
    }
}
