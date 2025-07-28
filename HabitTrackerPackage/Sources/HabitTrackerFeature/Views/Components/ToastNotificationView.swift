import SwiftUI

/// A toast notification system for displaying temporary messages to users
@MainActor
@Observable
public final class ToastManager {
    public static let shared = ToastManager()
    
    /// Currently displayed toasts
    public private(set) var toasts: [ToastNotification] = []
    
    /// Maximum number of toasts to show simultaneously
    private let maxToasts = 3
    
    private init() {}
    
    /// Show a toast notification
    public func show(
        message: String,
        type: ToastType = .info,
        duration: TimeInterval = 3.0,
        action: ToastAction? = nil
    ) {
        let toast = ToastNotification(
            message: message,
            type: type,
            duration: duration,
            action: action
        )
        
        // Add to beginning of array (newest first)
        toasts.insert(toast, at: 0)
        
        // Limit number of visible toasts
        if toasts.count > maxToasts {
            toasts.removeLast(toasts.count - maxToasts)
        }
        
        // Auto-dismiss after duration
        Task {
            try? await Task.sleep(for: .seconds(duration))
            dismiss(toast.id)
        }
    }
    
    /// Dismiss a specific toast
    public func dismiss(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.3)) {
            toasts.removeAll { $0.id == id }
        }
    }
    
    /// Clear all toasts
    public func clearAll() {
        withAnimation(.easeOut(duration: 0.3)) {
            toasts.removeAll()
        }
    }
    
    // MARK: - Convenience Methods
    
    public func showSuccess(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .success, duration: duration)
    }
    
    public func showError(_ message: String, action: ToastAction? = nil, duration: TimeInterval = 5.0) {
        show(message: message, type: .error, duration: duration, action: action)
    }
    
    public func showWarning(_ message: String, action: ToastAction? = nil, duration: TimeInterval = 4.0) {
        show(message: message, type: .warning, duration: duration, action: action)
    }
    
    public func showInfo(_ message: String, duration: TimeInterval = 3.0) {
        show(message: message, type: .info, duration: duration)
    }
}

// MARK: - Toast Models

public struct ToastNotification: Identifiable {
    public let id = UUID()
    public let message: String
    public let type: ToastType
    public let duration: TimeInterval
    public let action: ToastAction?
    public let timestamp = Date()
    
    public init(
        message: String,
        type: ToastType,
        duration: TimeInterval,
        action: ToastAction? = nil
    ) {
        self.message = message
        self.type = type
        self.duration = duration
        self.action = action
    }
}

public enum ToastType: String {
    case success
    case error
    case warning
    case info
    
    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success:
            return Color.green.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        case .warning:
            return Color.orange.opacity(0.1)
        case .info:
            return Color.blue.opacity(0.1)
        }
    }
}

public struct ToastAction {
    public let title: String
    public let handler: () -> Void
    
    public init(title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}

// MARK: - Toast View

struct ToastView: View {
    let toast: ToastNotification
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(toast.type.color)
            
            // Message
            Text(toast.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Action button
            if let action = toast.action {
                Button(action.title) {
                    action.handler()
                    onDismiss()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(toast.type.color)
            }
            
            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(toast.type.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .offset(x: dragOffset.width)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if abs(value.translation.width) > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
        .onTapGesture {
            if toast.action != nil {
                toast.action?.handler()
                onDismiss()
            }
        }
    }
}

// MARK: - Toast Container View

struct ToastContainerView: View {
    @State private var toastManager = ToastManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(toastManager.toasts) { toast in
                ToastView(toast: toast) {
                    toastManager.dismiss(toast.id)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false) // Allow touches to pass through to content below
        .zIndex(1000) // Ensure toasts appear above all other content
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Add toast notification capability to any view
    public func toastNotifications() -> some View {
        self.overlay {
            ToastContainerView()
                .padding(.top, 60) // Account for navigation bar
                .padding(.horizontal)
        }
    }
}

// MARK: - Error Integration

extension ErrorPresentationService {
    /// Show an error as a toast notification
    public func showErrorToast(
        _ error: any HabitTrackerError,
        actionLabel: String? = nil,
        actionHandler: (() -> Void)? = nil
    ) {
        let action: ToastAction? = if let actionLabel = actionLabel,
                                     let actionHandler = actionHandler {
            ToastAction(title: actionLabel, handler: actionHandler)
        } else {
            nil
        }
        
        ToastManager.shared.show(
            message: error.userMessage,
            type: toastTypeForError(error),
            duration: durationForError(error),
            action: action
        )
    }
    
    private func toastTypeForError(_ error: any HabitTrackerError) -> ToastType {
        switch error.severity {
        case .critical, .high:
            return .error
        case .medium:
            return .warning
        case .low:
            return .info
        }
    }
    
    private func durationForError(_ error: any HabitTrackerError) -> TimeInterval {
        switch error.severity {
        case .critical, .high:
            return 6.0
        case .medium:
            return 4.0
        case .low:
            return 3.0
        }
    }
}

// MARK: - Toast Accessibility

extension ToastView {
    private var accessibilityLabel: String {
        var label = "\(toast.type.rawValue): \(toast.message)"
        if toast.action != nil {
            label += ". \(toast.action!.title) available."
        }
        return label
    }
    
    private var accessibilityHint: String {
        if toast.action != nil {
            return "Double tap to \(toast.action!.title.lowercased()). Swipe right to dismiss."
        } else {
            return "Swipe right to dismiss."
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension ToastManager {
    /// Show sample toasts for testing
    public func showSamples() {
        showSuccess("Operation completed successfully!")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showWarning("This is a warning message", action: ToastAction(title: "Fix") {
                print("Fix action tapped")
            })
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showError("Something went wrong", action: ToastAction(title: "Retry") {
                print("Retry action tapped")
            })
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.showInfo("Here's some helpful information")
        }
    }
}
#endif