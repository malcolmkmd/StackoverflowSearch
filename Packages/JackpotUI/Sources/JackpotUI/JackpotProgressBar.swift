import SwiftUI

public struct JackpotProgressBar: View {
    private let progress: Double
    private let tint: Color?
    @Environment(\.jackpotTheme) private var theme

    public init(progress: Double, tint: Color? = nil) {
        self.progress = progress
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.fieldBorder)
                Capsule().fill(tint ?? theme.accent)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.25), value: progress)
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}
