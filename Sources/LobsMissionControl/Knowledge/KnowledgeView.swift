import SwiftUI

enum KnowledgeViewMode: String, CaseIterable {
    case feed = "Feed"
    case browse = "Browse"
}

struct KnowledgeView: View {
    @EnvironmentObject var vm: AppViewModel
    @StateObject private var service: KnowledgeService
    
    @State private var viewMode: KnowledgeViewMode = .feed
    @State private var selectedEntry: KnowledgeEntry? = nil
    @State private var showRequestResearchSheet = false
    
    init(apiService: APIService) {
        _service = StateObject(wrappedValue: KnowledgeService(apiService: apiService))
    }
    
    var body: some View {
        Group {
            if selectedEntry != nil {
                detailView
            } else {
                mainView
            }
        }
        .sheet(isPresented: $showRequestResearchSheet) {
            RequestResearchSheet(vm: vm, isPresented: $showRequestResearchSheet)
        }
        .task {
            // Load initial data
            await service.loadFeed()
        }
    }
    
    // MARK: - Main View
    
    private var mainView: some View {
        VStack(spacing: 0) {
            // Header with mode picker
            HStack(spacing: 16) {
                // Mode picker
                Picker("View Mode", selection: $viewMode) {
                    ForEach(KnowledgeViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
                
                // Request Research button
                Button {
                    showRequestResearchSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Request Research")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.borderedProminent)
                .help("Create a research task for the AI")
                
                // Refresh button
                Button {
                    Task {
                        await service.triggerSync()
                        await refreshCurrentView()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .buttonStyle(.bordered)
                .help("Refresh knowledge index")
            }
            .padding()
            
            Divider()
            
            // Content area
            if service.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = service.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Error loading knowledge")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await refreshCurrentView()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                contentView
            }
        }
        .onChange(of: viewMode) {
            Task {
                await refreshCurrentView()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .feed:
            KnowledgeFeedView(
                entries: service.feedEntries,
                onSelectEntry: { entry in
                    selectedEntry = entry
                }
            )
        case .browse:
            KnowledgeBrowseView(
                service: service,
                onSelectEntry: { entry in
                    selectedEntry = entry
                }
            )
        }
    }
    
    // MARK: - Detail View
    
    private var detailView: some View {
        KnowledgeEntryDetailView(
            entry: selectedEntry!,
            service: service,
            onBack: {
                selectedEntry = nil
            },
            onRequestResearch: {
                showRequestResearchSheet = true
            }
        )
    }
    
    // MARK: - Helpers
    
    private func refreshCurrentView() async {
        switch viewMode {
        case .feed:
            await service.loadFeed()
        case .browse:
            await service.browse(path: service.currentPath)
        }
    }
}

// MARK: - Request Research Sheet

private struct RequestResearchSheet: View {
    @ObservedObject var vm: AppViewModel
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var notes = ""
    @State private var targetPath = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Request Research")
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Title")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        TextField("e.g., Research multi-agent patterns", text: $title)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Research Question / Details")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Describe what you want researched")
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
                        Text("Target Path (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Suggest where findings should be written (e.g., research/agent-patterns/)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("research/<topic>/", text: $targetPath)
                            .textFieldStyle(.roundedBorder)
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
                            Image(systemName: "magnifyingglass.circle.fill")
                            Text("Create Research Task")
                        }
                    }
                }
                .disabled(title.isEmpty || isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 550, height: 500)
    }
    
    private func saveTask() {
        isSaving = true
        errorMessage = nil
        
        var fullNotes = notes
        if !targetPath.isEmpty {
            fullNotes += "\n\nTarget path: \(targetPath)"
        }
        
        Task {
            do {
                _ = try await vm.apiService?.addTask(
                    title: title,
                    owner: .lobs,
                    status: .inbox,
                    projectId: nil,
                    notes: fullNotes,
                    agent: "researcher"
                )
                
                await MainActor.run {
                    vm.flashSuccess("Research task created")
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
