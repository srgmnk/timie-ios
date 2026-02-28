import SwiftUI

struct ProgressiveBottomBlurOverlay: View {
    let height: CGFloat

    var body: some View {
        ZStack {
            // Blur layer with strongest effect at the bottom.
            Rectangle()
                .fill(.thickMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(1.0), location: 0.0),
                            .init(color: .black.opacity(0.95), location: 0.2),
                            .init(color: .black.opacity(0.65), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

            // Subtle dissolve fade to match the progressive "melt" behind the dial.
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.50), location: 0.0),
                    .init(color: Color.white.opacity(0.30), location: 0.35),
                    .init(color: Color.white.opacity(0.12), location: 0.7),
                    .init(color: Color.white.opacity(0.0), location: 1.0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}
