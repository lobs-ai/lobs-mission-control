import SwiftUI

enum MainSidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case chat = "Chat"
    case tasks = "Tasks"
    case memory = "Memory"
    case knowledge = "Knowledge"
    case calendar = "Calendar"
    case inbox = "Inbox"
    case status = "Status"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .tasks: return "checklist"
        case .memory: return "brain.head.profile"
        case .knowledge: return "books.vertical.fill"
        case .calendar: return "calendar"
        case .inbox: return "tray.fill"
        case .status: return "chart.bar.fill"
        case .settings: return "gearshape"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var orchestrator: OrchestratorManager
    
    @State private var selectedSection: MainSidebarSection = .home
    @StateObject private var chatViewModel: ChatViewModel
    @StateObject private var memoryViewModel: MemoryViewModel
    
    // Bindings for views that need isPresented
    @State private var inboxPresented: Bool = true
    @State private var statusPresented: Bool = true
    @State private var documentsPresented: Bool = true
    
    init() {
        // Initialize view models that need to persist across section switches
        let apiService = try! APIService()
        let chatService = ChatService()
        _chatViewModel = StateObject(wrappedValue: ChatViewModel(chatService: chatService, apiService: apiService))
        _memoryViewModel = StateObject(wrappedValue: MemoryViewModel(apiService: apiService))
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
    }
    
    // Sidebar: list of sections with icons
    var sidebarContent: some View {
        List(MainSidebarSection.allCases, selection: $selectedSection) { section in
            HStack {
                Label(section.rawValue, systemImage: section.icon)
                Spacer()
                
                // Show unread badge for inbox
                if section == .inbox && vm.unreadInboxCount > 0 {
                    Text("\(vm.unreadInboxCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
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
                onOpenInbox: { itemId in
                    selectedSection = .inbox
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
            ChatView(viewModel: chatViewModel)
                .navigationTitle("Chat")
            
        case .tasks:
            TasksContainerView()
                .environmentObject(vm)
                .navigationTitle("Tasks")
            
        case .memory:
            MemoryView(viewModel: memoryViewModel)
                .navigationTitle("Memory")
            
        case .knowledge:
            DocumentsView(vm: vm, isPresented: $documentsPresented)
                .navigationTitle("Knowledge")
            
        case .calendar:
            if let apiService = vm.apiService {
                CalendarView(apiService: apiService)
                    .navigationTitle("Calendar")
            } else {
                Text("API Service not available")
                    .navigationTitle("Calendar")
            }
            
        case .inbox:
            InboxView(vm: vm, isPresented: $inboxPresented)
                .navigationTitle("Inbox")
            
        case .status:
            if let apiService = vm.apiService {
                StatusView(apiService: apiService, isPresented: $statusPresented)
                    .navigationTitle("Status")
            } else {
                Text("API Service not available")
                    .navigationTitle("Status")
            }
            
        case .settings:
            SettingsView()
                .environmentObject(vm)
                .environmentObject(orchestrator)
                .navigationTitle("Settings")
        }
    }
}
