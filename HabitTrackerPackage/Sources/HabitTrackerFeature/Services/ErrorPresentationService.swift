import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Service responsible for presenting errors to users with actionable recovery options
@MainActor
@Observable
public final class ErrorPresentationService {
    public static let shared = ErrorPresentationService()
    
    // MARK: - Error Presentation State
    
    /// Currently presented error (if any)
    public private(set) var currentError: ErrorPresentation?
    
    /// Queue of errors waiting to be presented
    private var errorQueue: [ErrorPresentation] = []
    
    /// Whether an error is currently being presented
    public var isShowingError: Bool {
        currentError != nil
    }
    
    // MARK: - Error Presentation Model
    
    public struct ErrorPresentation: Identifiable {
        public let id = UUID()
        public let error: any HabitTrackerError
        public let presentationStyle: PresentationStyle
        public let dismissAction: (() -> Void)?
        public let recoveryActions: [RecoveryActionButton]
        
        public init(
            error: any HabitTrackerError,
            presentationStyle: PresentationStyle = .automatic,
            dismissAction: (() -> Void)? = nil,
            recoveryActions: [RecoveryActionButton] = []
        ) {
            self.error = error
            self.presentationStyle = presentationStyle
            self.dismissAction = dismissAction
            self.recoveryActions = recoveryActions.isEmpty ? 
                Self.defaultRecoveryActions(for: error) : recoveryActions
        }
        
        private static func defaultRecoveryActions(for error: any HabitTrackerError) -> [RecoveryActionButton] {
            error.recoveryActions.map { action in
                RecoveryActionButton(
                    action: action,
                    label: action.userFriendlyLabel,
                    style: action.buttonStyle
                )
            }
        }
    }
    
    public struct RecoveryActionButton: Identifiable {
        public let id = UUID()
        public let action: RecoveryAction
        public let label: String
        public let style: ButtonStyle
        public var handler: (() async -> Void)?
        
        public enum ButtonStyle {
            case primary
            case secondary
            case destructive
        }
    }
    
    public enum PresentationStyle {
        case automatic // System decides based on error severity
        case alert
        case banner
        case sheet
        case snackbar
    }
    
    // MARK: - Initialization
    
    private init() {
        // Register with ErrorHandlingService to receive errors
        ErrorHandlingService.shared.registerErrorCallback { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleError(error)
            }
        }
    }
    
    // MARK: - Public Interface
    
    /// Present an error to the user
    public func present(
        _ error: any HabitTrackerError,
        style: PresentationStyle = .automatic,
        dismissAction: (() -> Void)? = nil,
        customRecoveryActions: [RecoveryActionButton]? = nil
    ) {
        let presentation = ErrorPresentation(
            error: error,
            presentationStyle: style == .automatic ? determinePresentationStyle(for: error) : style,
            dismissAction: dismissAction,
            recoveryActions: customRecoveryActions ?? []
        )
        
        if currentError == nil {
            currentError = presentation
        } else {
            // Queue the error if one is already being shown
            errorQueue.append(presentation)
        }
    }
    
    /// Dismiss the current error
    public func dismiss() {
        currentError?.dismissAction?()
        currentError = nil
        
        // Show next error in queue if any
        if !errorQueue.isEmpty {
            currentError = errorQueue.removeFirst()
        }
    }
    
    /// Clear all queued errors
    public func clearQueue() {
        errorQueue.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: any HabitTrackerError) {
        // Only present errors that should be shown to users
        guard error.shouldShowToUser else { return }
        
        present(error)
    }
    
    private func determinePresentationStyle(for error: any HabitTrackerError) -> PresentationStyle {
        switch error.severity {
        case .critical, .high:
            return .alert
        case .medium:
            return .banner
        case .low:
            return .snackbar
        }
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Modifier to present errors from ErrorPresentationService
    public func errorPresentation() -> some View {
        self.modifier(ErrorPresentationModifier())
    }
}

struct ErrorPresentationModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var errorPresentation = ErrorPresentationService.shared
    @State private var showingAlert = false
    @State private var showingSheet = false
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let error = errorPresentation.currentError,
                   error.presentationStyle == .banner {
                    ErrorBannerView(error: error)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .overlay(alignment: .bottom) {
                if let error = errorPresentation.currentError,
                   error.presentationStyle == .snackbar {
                    ErrorSnackbarView(error: error)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(999)
                }
            }
            .alert(
                errorPresentation.currentError?.error.userMessage ?? "",
                isPresented: Binding(
                    get: { 
                        errorPresentation.currentError?.presentationStyle == .alert 
                    },
                    set: { _ in 
                        errorPresentation.dismiss()
                    }
                )
            ) {
                if let error = errorPresentation.currentError {
                    ForEach(error.recoveryActions) { action in
                        Button(action.label, role: action.style == .destructive ? .destructive : nil) {
                            Task {
                                await action.handler?()
                                errorPresentation.dismiss()
                            }
                        }
                    }
                    
                    Button("Dismiss", role: .cancel) {
                        errorPresentation.dismiss()
                    }
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { 
                        errorPresentation.currentError?.presentationStyle == .sheet 
                    },
                    set: { _ in 
                        errorPresentation.dismiss()
                    }
                )
            ) {
                if let error = errorPresentation.currentError {
                    ErrorSheetView(error: error)
                }
            }
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let error: ErrorPresentationService.ErrorPresentation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: error.error.iconName)
                    .foregroundStyle(error.error.iconColor)
                
                Text(error.error.userMessage)
                    .font(.subheadline)
                    .lineLimit(isExpanded ? nil : 2)
                
                Spacer()
                
                Button {
                    ErrorPresentationService.shared.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            if isExpanded && !error.recoveryActions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(error.recoveryActions) { action in
                        Button {
                            Task {
                                await action.handler?()
                                ErrorPresentationService.shared.dismiss()
                            }
                        } label: {
                            Text(action.label)
                                .font(.caption)
                        }
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding()
        .background {
            #if canImport(UIKit)
            Color(UIColor.secondarySystemBackground)
            #else
            Color.gray.opacity(0.1)
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
        .padding(.horizontal)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - Error Snackbar View

struct ErrorSnackbarView: View {
    let error: ErrorPresentationService.ErrorPresentation
    @State private var timeRemaining = 5
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack {
            Image(systemName: error.error.iconName)
                .foregroundStyle(error.error.iconColor)
            
            Text(error.error.userMessage)
                .font(.subheadline)
                .lineLimit(2)
            
            Spacer()
            
            if !error.recoveryActions.isEmpty,
               let primaryAction = error.recoveryActions.first {
                Button(primaryAction.label) {
                    Task {
                        await primaryAction.handler?()
                        ErrorPresentationService.shared.dismiss()
                    }
                }
                .font(.caption)
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
            }
        }
        .padding()
        .background {
            #if canImport(UIKit)
            Color(UIColor.secondarySystemBackground)
            #else
            Color.gray.opacity(0.1)
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
        .padding(.horizontal)
        .padding(.bottom, 20)
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                ErrorPresentationService.shared.dismiss()
            }
        }
        .onTapGesture {
            ErrorPresentationService.shared.dismiss()
        }
    }
}

// MARK: - Error Sheet View

struct ErrorSheetView: View {
    let error: ErrorPresentationService.ErrorPresentation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Error icon and title
                VStack(spacing: 16) {
                    Image(systemName: error.error.iconName)
                        .font(.system(size: 48))
                        .foregroundStyle(error.error.iconColor)
                    
                    Text(error.error.userMessage)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Technical details (if in debug mode)
                #if DEBUG
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technical Details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Text(error.error.technicalDetails)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                #endif
                
                Spacer()
                
                // Recovery actions
                VStack(spacing: 12) {
                    ForEach(error.recoveryActions) { action in
                        Button {
                            Task {
                                await action.handler?()
                                dismiss()
                                ErrorPresentationService.shared.dismiss()
                            }
                        } label: {
                            Text(action.label)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RecoveryButtonStyle(style: action.style))
                        .controlSize(.large)
                    }
                    
                    Button("Dismiss") {
                        dismiss()
                        ErrorPresentationService.shared.dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if canImport(UIKit)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        ErrorPresentationService.shared.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                #else
                ToolbarItem {
                    Button {
                        dismiss()
                        ErrorPresentationService.shared.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Button Styles

struct RecoveryButtonStyle: ButtonStyle {
    let style: ErrorPresentationService.RecoveryActionButton.ButtonStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(for: style))
            .padding()
            .background(backgroundColor(for: style))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
    
    private func foregroundColor(for style: ErrorPresentationService.RecoveryActionButton.ButtonStyle) -> Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .primary
        }
    }
    
    private func backgroundColor(for style: ErrorPresentationService.RecoveryActionButton.ButtonStyle) -> Color {
        switch style {
        case .primary:
            return .blue
        case .secondary:
            return Color.gray.opacity(0.2)
        case .destructive:
            return .red
        }
    }
}

// MARK: - Recovery Action Extensions

extension RecoveryAction {
    var userFriendlyLabel: String {
        switch self {
        case .retry:
            return "Try Again"
        case .checkSettings:
            return "Check Settings"
        case .enableLocation:
            return "Enable Location"
        case .checkInternet:
            return "Check Connection"
        case .restart:
            return "Restart App"
        case .contact:
            return "Contact Support"
        case .ignore:
            return "Ignore"
        }
    }
    
    var buttonStyle: ErrorPresentationService.RecoveryActionButton.ButtonStyle {
        switch self {
        case .retry, .enableLocation:
            return .primary
        case .checkSettings, .checkInternet:
            return .secondary
        case .restart:
            return .destructive
        case .contact, .ignore:
            return .secondary
        }
    }
}

// MARK: - Error Extension

extension HabitTrackerError {
    var shouldShowToUser: Bool {
        // Don't show low severity technical errors to users
        if severity == .low && category == .technical {
            return false
        }
        return true
    }
    
    var iconName: String {
        switch category {
        case .location:
            return "location.slash"
        case .network:
            return "wifi.slash"
        case .data:
            return "exclamationmark.icloud"
        case .validation:
            return "exclamationmark.triangle"
        case .configuration:
            return "gear.badge.xmark"
        case .synchronization:
            return "arrow.triangle.2.circlepath.exclamationmark"
        case .technical:
            return "wrench.and.screwdriver"
        }
    }
    
    var iconColor: Color {
        switch severity {
        case .critical, .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .yellow
        }
    }
}