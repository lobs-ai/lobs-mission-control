import SwiftUI

// MARK: - Error Toast Component

/// A banner-style toast notification for displaying errors and success messages.
/// Appears at the top of the view with an icon, message, and dismiss button.
struct ErrorToastBanner: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void
    
    enum ToastType {
        case error
        case success
        case warning
        case info
        
        var color: Color {
            switch self {
            case .error: return .red
            case .success: return .green
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(.white)
                .font(.body)
            
            Text(message)
                .font(.callout.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.color.opacity(0.92))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .padding(.horizontal, 20)
    }
}

// MARK: - Error Toast View Modifier

/// View modifier that adds error and success toast overlays to any view.
/// Automatically displays banners from AppViewModel's errorBanner and successBanner properties.
struct ErrorToastModifier: ViewModifier {
    @EnvironmentObject var vm: AppViewModel
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    if let error = vm.errorBanner {
                        ErrorToastBanner(
                            message: error,
                            type: .error,
                            onDismiss: { vm.errorBanner = nil }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000) // Ensure toasts appear above other content
                    }
                    
                    if let success = vm.successBanner {
                        ErrorToastBanner(
                            message: success,
                            type: .success,
                            onDismiss: { vm.successBanner = nil }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: vm.errorBanner)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: vm.successBanner)
                .padding(.top, 8)
            }
    }
}

// MARK: - View Extension

extension View {
    /// Adds error toast support to the view.
    /// Requires AppViewModel to be in the environment.
    ///
    /// Usage:
    /// ```swift
    /// MainView()
    ///     .errorToast()
    ///     .environmentObject(appViewModel)
    /// ```
    func errorToast() -> some View {
        modifier(ErrorToastModifier())
    }
}

// MARK: - Preview Support

#if DEBUG
struct ErrorToast_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Content below toasts")
                .font(.title)
            
            Spacer()
            
            VStack(spacing: 12) {
                ErrorToastBanner(
                    message: "Failed to save task. Please try again.",
                    type: .error,
                    onDismiss: {}
                )
                
                ErrorToastBanner(
                    message: "Task created successfully!",
                    type: .success,
                    onDismiss: {}
                )
                
                ErrorToastBanner(
                    message: "This action cannot be undone.",
                    type: .warning,
                    onDismiss: {}
                )
                
                ErrorToastBanner(
                    message: "Server is processing your request...",
                    type: .info,
                    onDismiss: {}
                )
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 600, height: 400)
    }
}
#endif
