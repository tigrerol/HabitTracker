import SwiftUI

/// iOS-style page dots indicator. Each dot is tappable for accessibility and discoverability.
struct PageDotsIndicator: View {
    let currentIndex: Int
    let count: Int
    let labels: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Circle()
                        .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 7, height: 7)
                        .contentShape(Rectangle().inset(by: -8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(labels[safe: index] ?? "Page \(index + 1)")
                .accessibilityAddTraits(index == currentIndex ? [.isSelected] : [])
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
