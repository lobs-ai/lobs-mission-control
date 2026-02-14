import SwiftUI

enum MainSidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case chat = "Chat"
    case tasks = "Tasks"
    case memory = "Memory"
    case knowledge = "Knowledge"
    case workTracker = "Work Tracker"
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
        case .workTracker: return "clock.badge.checkmark.fill"
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
    @State private var chatViewModel: ChatViewModel?
    @State private var memoryViewModel: MemoryViewModel?
    
    // Bindings for views that need isPresented
    @State private var inboxPresented: Bool = true
    @State private var statusPresented: Bool = true
    @State private var documentsPresented: Bool = true
    
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
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let error = vm.errorBanner {
                    bannerView(message: error, color: .red, icon: "xmark.circle.fill") {
                        vm.errorBanner = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let success = vm.successBanner {
                    bannerView(message: success, color: .green, icon: "checkmark.circle.fill") {
                        vm.successBanner = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: vm.errorBanner)
            .animation(.spring(response: 0.3), value: vm.successBanner)
            .padding(.top, 8)
        }
    }
    
    private func bannerView(message: String, color: Color, icon: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(message)
                .font(.callout.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(color.opacity(0.9))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
        .padding(.horizontal, 20)
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
            TopicBrowserView(vm: vm, isPresented: $documentsPresented)
                .navigationTitle("Knowledge")
            
        case .workTracker:
            WorkTrackerView(vm: vm)
                .navigationTitle("Work Tracker")
            
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
