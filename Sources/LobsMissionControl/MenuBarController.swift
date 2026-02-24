import AppKit
import Combine
import Foundation

/// Menu bar widget for ambient awareness of the current / next task.
///
/// Lives inside the main app target (not a separate menu bar app).
@MainActor
final class MenuBarController: NSObject {
  private var statusItem: NSStatusItem?
  private var menu: NSMenu?

  private weak var vm: AppViewModel?
  private var cancellables: Set<AnyCancellable> = []

  func attach(viewModel: AppViewModel) {
    self.vm = viewModel

    if statusItem == nil {
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      item.button?.title = "Loading…"
      item.button?.toolTip = "Lobs Mission Control"
      self.statusItem = item

      let menu = NSMenu(title: "Lobs Mission Control")
      self.menu = menu
      item.menu = menu
    }

    // Rebuild whenever tasks/projects/inbox/agents change.
    cancellables.removeAll()
    viewModel.$tasks
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)

    viewModel.$projects
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)

    viewModel.$inboxItems
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)

    viewModel.$agentStatuses
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)

    refresh()
  }

  func detach() {
    cancellables.removeAll()
    vm = nil

    if let item = statusItem {
      NSStatusBar.system.removeStatusItem(item)
    }

    statusItem = nil
    menu = nil
  }

  private func refresh() {
    guard let statusItem, let menu else { return }

    let stats = computeStats()

    // Title: compact with symbols and numbers
    let titleParts = buildTitleParts(stats: stats)
    let title = titleParts.isEmpty ? "Lobs" : titleParts.joined(separator: " ")
    statusItem.button?.title = title
    statusItem.button?.toolTip = buildTooltip(stats: stats)

    // Menu
    menu.removeAllItems()

    // Task counts section
    let tasksHeader = NSMenuItem(title: "Tasks", action: nil, keyEquivalent: "")
    tasksHeader.isEnabled = false
    menu.addItem(tasksHeader)

    let inboxItem = NSMenuItem(title: "  📥 Inbox: \(stats.inboxCount)", action: #selector(showInbox(_:)), keyEquivalent: "")
    inboxItem.target = self
    menu.addItem(inboxItem)

    let activeItem = NSMenuItem(title: "  ⚡ Active: \(stats.activeCount)", action: #selector(showActiveTasks(_:)), keyEquivalent: "")
    activeItem.target = self
    menu.addItem(activeItem)

    let waitingItem = NSMenuItem(title: "  ⏸ Waiting: \(stats.waitingCount)", action: #selector(showWaitingTasks(_:)), keyEquivalent: "")
    waitingItem.target = self
    menu.addItem(waitingItem)

    if stats.unreadInboxCount > 0 {
      let unreadItem = NSMenuItem(title: "  ⚠️ Unread Items: \(stats.unreadInboxCount)", action: #selector(showInbox(_:)), keyEquivalent: "")
      unreadItem.target = self
      menu.addItem(unreadItem)
    }

    menu.addItem(.separator())

    // Agents section
    let agentsHeader = NSMenuItem(title: "Agents", action: nil, keyEquivalent: "")
    agentsHeader.isEnabled = false
    menu.addItem(agentsHeader)

    let workingItem = NSMenuItem(title: "  🤖 Working: \(stats.workingAgents)", action: #selector(showTeam(_:)), keyEquivalent: "")
    workingItem.target = self
    menu.addItem(workingItem)

    let idleItem = NSMenuItem(title: "  💤 Idle: \(stats.idleAgents)", action: #selector(showTeam(_:)), keyEquivalent: "")
    idleItem.target = self
    menu.addItem(idleItem)

    menu.addItem(.separator())

    // Actions
    let open = NSMenuItem(title: "Open Dashboard", action: #selector(openDashboard(_:)), keyEquivalent: "")
    open.target = self
    menu.addItem(open)

    let reload = NSMenuItem(title: "Refresh", action: #selector(refreshNow(_:)), keyEquivalent: "r")
    reload.keyEquivalentModifierMask = [.command]
    reload.target = self
    menu.addItem(reload)

    menu.addItem(.separator())

    let quit = NSMenuItem(title: "Quit Lobs Mission Control", action: #selector(quitApp(_:)), keyEquivalent: "q")
    quit.keyEquivalentModifierMask = [.command]
    quit.target = self
    menu.addItem(quit)
  }

  private struct MenuBarStats {
    var inboxCount: Int = 0
    var activeCount: Int = 0
    var waitingCount: Int = 0
    var unreadInboxCount: Int = 0
    var workingAgents: Int = 0
    var idleAgents: Int = 0
  }

  private func computeStats() -> MenuBarStats {
    guard let vm else { return MenuBarStats() }

    var stats = MenuBarStats()

    let projectsById = Dictionary(uniqueKeysWithValues: vm.projects.map { ($0.id, $0) })

    // Count tasks by status (excluding archived projects)
    for task in vm.tasks {
      let pid = task.projectId ?? "default"
      if let p = projectsById[pid], (p.archived ?? false) == true { continue }

      switch task.status {
      case .inbox:
        stats.inboxCount += 1
      case .active:
        stats.activeCount += 1
      case .waitingOn:
        stats.waitingCount += 1
      case .completed, .rejected, .other:
        break
      }
    }

    // Count unread inbox items
    stats.unreadInboxCount = vm.inboxItems.filter { !$0.isRead }.count

    // Count agents by status
    for (_, agent) in vm.agentStatuses {
      if agent.status == "working" || agent.status == "thinking" || agent.status == "finalizing" {
        stats.workingAgents += 1
      } else if agent.status == "idle" {
        stats.idleAgents += 1
      }
    }

    return stats
  }

  private func buildTitleParts(stats: MenuBarStats) -> [String] {
    var parts: [String] = []

    // Show counts only if non-zero to keep it compact
    if stats.inboxCount > 0 {
      parts.append("📥\(stats.inboxCount)")
    }

    if stats.activeCount > 0 {
      parts.append("⚡\(stats.activeCount)")
    }

    if stats.waitingCount > 0 {
      parts.append("⏸\(stats.waitingCount)")
    }

    if stats.workingAgents > 0 {
      parts.append("🤖\(stats.workingAgents)")
    }

    if stats.unreadInboxCount > 0 {
      parts.append("⚠️\(stats.unreadInboxCount)")
    }

    return parts
  }

  private func buildTooltip(stats: MenuBarStats) -> String {
    var lines: [String] = []

    lines.append("Lobs Mission Control")
    lines.append("")
    lines.append("Tasks:")
    lines.append("  📥 Inbox: \(stats.inboxCount)")
    lines.append("  ⚡ Active: \(stats.activeCount)")
    lines.append("  ⏸ Waiting: \(stats.waitingCount)")

    if stats.unreadInboxCount > 0 {
      lines.append("  ⚠️ Unread Items: \(stats.unreadInboxCount)")
    }

    lines.append("")
    lines.append("Agents:")
    lines.append("  🤖 Working: \(stats.workingAgents)")
    lines.append("  💤 Idle: \(stats.idleAgents)")

    return lines.joined(separator: "\n")
  }

  @objc private func showInbox(_ sender: Any?) {
    openDashboard(nil)
  }

  @objc private func showActiveTasks(_ sender: Any?) {
    openDashboard(nil)
  }

  @objc private func showWaitingTasks(_ sender: Any?) {
    openDashboard(nil)
  }

  @objc private func showTeam(_ sender: Any?) {
    openDashboard(nil)
  }

  @objc private func openDashboard(_ sender: Any?) {
    NSApp.activate(ignoringOtherApps: true)
    // Bring an existing window forward if one exists.
    if let win = NSApp.windows.first {
      win.makeKeyAndOrderFront(nil)
    }
  }

  @objc private func refreshNow(_ sender: Any?) {
    vm?.silentReload()
  }

  @objc private func quitApp(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}

@MainActor
final class LobsMissionControlAppDelegate: NSObject, NSApplicationDelegate {
  let menuBar = MenuBarController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // AppViewModel is attached from SwiftUI onAppear.
  }
}
