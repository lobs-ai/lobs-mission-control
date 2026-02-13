import SwiftUI

struct HoverIconButton: View {
  let icon: String
  let tooltip: String
  var activeBg: Color? = nil
  var shortcut: String? = nil
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.body)
        .padding(6)
        .background(activeBg ?? (isHovering ? Color.primary.opacity(0.08) : Theme.subtle))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.primary.opacity(isHovering ? 0.12 : 0), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.06 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
    .buttonStyle(.plain)
    .onHover { h in isHovering = h }
    .help(tooltip)
  }
}
