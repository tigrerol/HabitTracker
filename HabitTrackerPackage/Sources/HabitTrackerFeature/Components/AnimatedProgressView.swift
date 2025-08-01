import SwiftUI

// MARK: - Animated Circular Progress

public struct AnimatedCircularProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let accentColor: Color?
    @Environment(\.themeManager) private var themeManager
    
    public init(progress: Double, size: CGFloat = 60, lineWidth: CGFloat = 6, accentColor: Color? = nil) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.accentColor = accentColor
    }
    
    private var effectiveAccentColor: Color {
        accentColor ?? themeManager.currentAccentColor
    }
    
    public var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [effectiveAccentColor.opacity(0.5), effectiveAccentColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
            
            // Progress Text
            Text("\(Int(progress * 100))%")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundColor(effectiveAccentColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animated Linear Progress

public struct AnimatedLinearProgress: View {
    let progress: Double
    let height: CGFloat
    let accentColor: Color?
    @Environment(\.themeManager) private var themeManager
    
    public init(progress: Double, height: CGFloat = 8, accentColor: Color? = nil) {
        self.progress = progress
        self.height = height
        self.accentColor = accentColor
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                
                // Progress Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [(accentColor ?? themeManager.currentAccentColor).opacity(0.7), (accentColor ?? themeManager.currentAccentColor)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

// MARK: - Animated Ring Progress

public struct AnimatedRingProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let primaryColor: Color?
    let secondaryColor: Color?
    @Environment(\.themeManager) private var themeManager
    
    public init(
        progress: Double,
        size: CGFloat = 80,
        lineWidth: CGFloat = 8,
        primaryColor: Color? = nil,
        secondaryColor: Color? = nil
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }
    
    private var effectivePrimaryColor: Color {
        primaryColor ?? themeManager.currentAccentColor
    }
    
    private var effectiveSecondaryColor: Color {
        secondaryColor ?? Theme.Colors.accentGreen
    }
    
    public var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: lineWidth)
            
            // Secondary progress ring (slight offset)
            Circle()
                .trim(from: 0, to: progress * 0.9)
                .stroke(
                    effectiveSecondaryColor.opacity(0.3),
                    style: StrokeStyle(lineWidth: lineWidth * 1.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0).delay(0.1), value: progress)
            
            // Primary progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [effectivePrimaryColor, effectivePrimaryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                .shadow(color: effectivePrimaryColor.opacity(0.3), radius: 3, x: 0, y: 0)
            
            // Center content
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(effectivePrimaryColor)
                
                Text("%")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(Color.gray)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animated Step Progress

public struct AnimatedStepProgress: View {
    let currentStep: Int
    let totalSteps: Int
    let accentColor: Color?
    @Environment(\.themeManager) private var themeManager
    
    public init(currentStep: Int, totalSteps: Int, accentColor: Color? = nil) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.accentColor = accentColor
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step < currentStep ? (accentColor ?? themeManager.currentAccentColor) : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep - 1 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStep)
            }
        }
    }
}