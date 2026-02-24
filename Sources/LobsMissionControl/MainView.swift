import SwiftUI

enum MainSidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case chat = "Chat"
    case tasks = "Tasks"
    case memory = "Memory"
    case knowledge = "Knowledge"
    case workTracker = "Work Tracker"
    case workflows = "Workflows"
    case intelligence = "Intelligence"
    case status = "Status"
    case usage = "Usage"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .tasks: return "checklist"
        case .memory: return "brain.head.profile"
        case .knowledge: return "books.vertical.fill"
        case .workTracker: return "clock.badge.checkmark.fill"
        case .workflows: return "arrow.triangle.branch"
        case .intelligence: return "brain.fill"
        case .status: return "chart.bar.fill"
        case .usage: return "chart.pie.fill"
        case .settings: return "gearshape"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var orchestrator: OrchestratorManager
    
    @State private var selectedSection: MainSidebarSection = .home
    @State private var chatViewModel: ChatViewModel?
    @State private var memoryViewModel: MemoryViewModel?
    
    // Bindings for views that need isPresented
    @State private var statusPresented: Bool = true
    
    // Command Palette state
    @State private var showCommandPalette: Bool = false
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: vm.apiService != nil) { hasAPI in
            if hasAPI, let apiService = vm.apiService {
                if chatViewModel == nil {
                    let chatService = ChatService()
                    chatViewModel = ChatViewModel(chatService: chatService, apiService: apiService)
                }
                if memoryViewModel == nil {
                    memoryViewModel = MemoryViewModel(apiService: apiService)
                }
            }
        }
        .onAppear {
            if let apiService = vm.apiService {
                if chatViewModel == nil {
                    let chatService = ChatService()
                    chatViewModel = ChatViewModel(chatService: chatService, apiService: apiService)
                }
                if memoryViewModel == nil {
                    memoryViewModel = MemoryViewModel(apiService: apiService)
                }
            }
        }
        .errorToast() // Unified error toast system
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView(
                vm: vm,
                isPresented: $showCommandPalette,
                onNewTask: {
                    selectedSection = .tasks
                },
                onOpenMemory: {
                    selectedSection = .memory
                },
                onOpenChat: {
                    selectedSection = .chat
                },
                onOpenStatus: {
                    selectedSection = .status
                },
                onOpenSettings: {
                    selectedSection = .settings
                },
                onOpenKnowledge: {
                    selectedSection = .knowledge
                },
                onOpenWorkTracker: {
                    selectedSection = .workTracker
                },
                loadedMemories: memoryViewModel?.memories ?? []
            )
            .frame(width: 600, height: 400)
        }
        .background(
            KeyboardShortcutHandler {
                showCommandPalette.toggle()
            }
        )
    }
    
    // Sidebar: list of sections with icons
    var sidebarContent: some View {
        List(MainSidebarSection.allCases, selection: $selectedSection) { section in
            HStack {
                Label(section.rawValue, systemImage: section.icon)
                Spacer()
                
                // Show pending reviews badge for intelligence
                if section == .intelligence && vm.pendingIntelligenceReviews > 0 {
                    Text("\(vm.pendingIntelligenceReviews)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .tag(section)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
        .navigationTitle("Mission Control")
    }
    
    // Detail: switch on selected section
    @ViewBuilder
    var detailContent: some View {
        switch selectedSection {
        case .home:
            CommandCenterView(
                vm: vm,
                onSelectProject: { projectId in
                    // Switch to tasks view when a project is selected
                    selectedSection = .tasks
                },
                onNewTask: {
                    selectedSection = .tasks
                },
                onOpenMemory: {
                    selectedSection = .memory
                },
                onOpenStatus: {
                    selectedSection = .status
                },
                onStartResearch: {
                    selectedSection = .knowledge
                },
                onOpenChat: {
                    selectedSection = .chat
                }
            )
            .navigationTitle("Home")
            
        case .chat:
            if let chatVM = chatViewModel {
                ChatView(viewModel: chatVM)
                    .navigationTitle("Chat")
            } else {
                ProgressView("Loading...")
                    .navigationTitle("Chat")
            }
            
        case .tasks:
            TasksContainerView()
                .environmentObject(vm)
                .navigationTitle("Tasks")
            
        case .memory:
            if let memoryVM = memoryViewModel {
                MemoryView(viewModel: memoryVM)
                    .navigationTitle("Memory")
            } else {
                ProgressView("Loading...")
                    .navigationTitle("Memory")
            }
            
        case .knowledge:
            if let apiService = vm.apiService {
                KnowledgeView(apiService: apiService)
                    .navigationTitle("Knowledge")
            } else {
                Text("API Service not available")
                    .navigationTitle("Knowledge")
            }
            
        case .workTracker:
            WorkTrackerView(vm: vm)
                .navigationTitle("Work Tracker")
            
        case .workflows:
            if let apiService = vm.apiService {
                WorkflowsView(apiService: apiService)
                    .navigationTitle("Workflows")
            } else {
                Text("API Service not available")
                    .navigationTitle("Workflows")
            }

        case .intelligence:
            IntelligenceView(vm: vm)
                .navigationTitle("Intelligence")
            
        case .status:
            if let apiService = vm.apiService {
                StatusView(apiService: apiService, isPresented: $statusPresented)
                    .navigationTitle("Status")
            } else {
                Text("API Service not available")
                    .navigationTitle("Status")
            }
            
        case .usage:
            if let apiService = vm.apiService {
                UsageView(apiService: apiService, isPresented: $statusPresented)
                    .navigationTitle("Usage")
            } else {
                Text("API Service not available")
                    .navigationTitle("Usage")
            }
            
        case .settings:
            SettingsView()
                .environmentObject(vm)
                .environmentObject(orchestrator)
                .navigationTitle("Settings")
        }
    }
}

// MARK: - Keyboard Shortcut Handler

/// Captures ⌘K globally to show the command palette
private struct KeyboardShortcutHandler: NSViewRepresentable {
    let onCommandK: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // Store closure in coordinator
        context.coordinator.onCommandK = onCommandK
        
        // Install local event monitor for ⌘K
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Check for ⌘K (keyCode 40 = 'k', modifiers = command)
            if event.keyCode == 40 && event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) {
                DispatchQueue.main.async {
                    context.coordinator.onCommandK?()
                }
                return nil // consume event
            }
            return event
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update closure in coordinator
        context.coordinator.onCommandK = onCommandK
    }
    
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        // Clean up event monitor
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var monitor: Any?
        var onCommandK: (() -> Void)?
    }
}
