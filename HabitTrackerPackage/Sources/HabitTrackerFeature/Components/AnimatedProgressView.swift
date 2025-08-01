import SwiftUI

// MARK: - Animated Circular Progress

public struct AnimatedCircularProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let accentColor: Color
    
    public init(progress: Double, size: CGFloat = 60, lineWidth: CGFloat = 6, accentColor: Color = Theme.accent) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.accentColor = accentColor
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
                        colors: [accentColor.opacity(0.5), accentColor],
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
                .foregroundColor(accentColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Animated Linear Progress

public struct AnimatedLinearProgress: View {
    let progress: Double
    let height: CGFloat
    let accentColor: Color
    
    public init(progress: Double, height: CGFloat = 8, accentColor: Color = Theme.accent) {
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
                            colors: [accentColor.opacity(0.7), accentColor],
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
    let primaryColor: Color
    let secondaryColor: Color
    
    public init(
        progress: Double,
        size: CGFloat = 80,
        lineWidth: CGFloat = 8,
        primaryColor: Color = Theme.accent,
        secondaryColor: Color = Theme.Colors.accentGreen
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
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
                    secondaryColor.opacity(0.3),
                    style: StrokeStyle(lineWidth: lineWidth * 1.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0).delay(0.1), value: progress)
            
            // Primary progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [primaryColor, primaryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
                .shadow(color: primaryColor.opacity(0.3), radius: 3, x: 0, y: 0)
            
            // Center content
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundColor(primaryColor)
                
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
    let accentColor: Color
    
    public init(currentStep: Int, totalSteps: Int, accentColor: Color = Theme.accent) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.accentColor = accentColor
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step < currentStep ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step == currentStep - 1 ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: currentStep)
            }
        }
    }
}