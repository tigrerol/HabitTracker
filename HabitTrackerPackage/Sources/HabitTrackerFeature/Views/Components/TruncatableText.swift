import SwiftUI

/// Text with a hard line limit that reveals the full string in an anchored
/// popover when tapped — but only if it is actually truncated. Untruncated
/// text stays hit-transparent, so enclosing buttons (e.g. subtask rows)
/// keep receiving taps.
///
/// Font, foreground style, and text alignment are inherited from the
/// environment, so call sites style it like a plain `Text`.
struct TruncatableText: View {
    let text: String
    let lineLimit: Int
    var strikethrough: Bool = false

    @State private var visibleHeight: CGFloat = 0
    @State private var fullHeight: CGFloat = 0
    @State private var showingFullText = false

    private var isTruncated: Bool {
        fullHeight > visibleHeight + 1
    }

    var body: some View {
        Text(text)
            .strikethrough(strikethrough)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                visibleHeight = height
            }
            .background(
                // Hidden twin laid out without a line limit at the same width;
                // a taller twin means the visible text is truncated.
                Text(text)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        fullHeight = height
                    }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showingFullText = true
            }
            .allowsHitTesting(isTruncated)
            .popover(isPresented: $showingFullText) {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxWidth: 320)
                .frame(maxHeight: 400)
                .fixedSize(horizontal: false, vertical: true)
                .presentationCompactAdaptation(.popover)
            }
            .accessibilityHint(isTruncated ? Text("TruncatableText.ShowFullTextHint", bundle: .module) : Text(verbatim: ""))
    }
}

#Preview {
    VStack(spacing: 24) {
        TruncatableText(
            text: "A very long habit title that certainly does not fit on two lines of a phone screen no matter how you rotate it",
            lineLimit: 2
        )
        .font(.system(.title2, design: .rounded, weight: .bold))
        .multilineTextAlignment(.center)

        TruncatableText(text: "Short name", lineLimit: 2)

        TruncatableText(
            text: "A completed subtask with an extremely long descriptive name that gets cut off",
            lineLimit: 1,
            strikethrough: true
        )
    }
    .padding(40)
}
