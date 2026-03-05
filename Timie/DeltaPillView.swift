import SwiftUI

struct DeltaPillView: View {
    enum PillMode {
        case now
        case future
        case past
    }

    let mode: PillMode
    let deltaText: String
    let onDoubleTapReset: () -> Void

    private let accentOrange = Color(red: 0xE8 / 255, green: 0x53 / 255, blue: 0x34 / 255)
    private let labelBlack = Color(red: 0x22 / 255, green: 0x22 / 255, blue: 0x22 / 255)

    var body: some View {
        HStack(spacing: 2) {
            switch mode {
            case .now:
                Text("Now")
            case .future:
                Image(systemName: "plus.circle.fill")
                Text(deltaText)
                    .monospacedDigit()
            case .past:
                Image(systemName: "minus.circle.fill")
                Text(deltaText)
                    .monospacedDigit()
            }
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .lineSpacing(0)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 30)
        .fixedSize(horizontal: true, vertical: false)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 100, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 100, style: .continuous))
        .highPriorityGesture(TapGesture(count: 2).onEnded {
            onDoubleTapReset()
        })
    }

    private var backgroundColor: Color {
        switch mode {
        case .now:
            return Color.black.opacity(0.2)
        case .past:
            return labelBlack
        case .future:
            return accentOrange
        }
    }
}
