import SwiftUI

/// The shell, drawn as placeholders, for the one launch that has no cached config.
///
/// Shaped like the real thing — header, verticals strip, content, bottom bar — so that when
/// config lands the layout does not shift. A generic spinner would be less work and worse: the
/// content jumps into place from nothing, which reads as slower than it is even when it isn't.
public struct JackpotLaunchSkeleton: View {
    private let showsBanner: Bool
    private let gridRows: Int

    @Environment(\.jackpotTheme) private var theme
    @State private var shimmer = false

    public init(showsBanner: Bool = true, gridRows: Int = 3) {
        self.showsBanner = showsBanner
        self.gridRows = gridRows
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            strip
            ScrollView {
                VStack(spacing: theme.spacing) {
                    if showsBanner { block(height: 170) }
                    ForEach(0..<gridRows, id: \.self) { _ in tileRow }
                }
                .padding(.horizontal, 16)
                .padding(.top, theme.spacing)
            }
            bottomBar
        }
        .background(theme.surface)
        .redacted(reason: .placeholder)
        .shimmering(isActive: shimmer)
        .onAppear { shimmer = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }

    private var header: some View {
        HStack(spacing: 12) {
            block(width: 24, height: 18)
            Spacer()
            block(width: 130, height: 20)
            Spacer()
            block(width: 78, height: 34)
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
    }

    private var strip: some View {
        HStack(spacing: 18) {
            ForEach(0..<5, id: \.self) { _ in
                VStack(spacing: 6) {
                    block(width: 26, height: 22)
                    block(width: 44, height: 9)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .padding(.horizontal, 16)
    }

    private var tileRow: some View {
        HStack(spacing: theme.spacing) {
            block(height: 96)
            block(height: 96)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                VStack(spacing: 5) {
                    block(width: 24, height: 22)
                    block(width: 40, height: 9)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 62)
        .background(theme.surfaceElevated)
    }

    @ViewBuilder
    private func block(width: CGFloat? = nil, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6).fill(theme.fieldBackground)
        if let width {
            shape.frame(width: width, height: height)
        } else {
            shape.frame(maxWidth: .infinity).frame(height: height)
        }
    }
}

/// A single sweep across placeholder content.
///
/// Deliberately slow and low-contrast: a fast, bright shimmer draws the eye to the fact that
/// nothing has loaded. Respects Reduce Motion — it holds still rather than animating.
public struct JackpotShimmer: ViewModifier {
    private let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    public init(isActive: Bool) { self.isActive = isActive }

    public func body(content: Content) -> some View {
        if isActive, !reduceMotion {
            content
                .overlay(
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.06), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * 0.6)
                        .offset(x: phase * proxy.size.width * 1.6)
                    }
                    .allowsHitTesting(false)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

public extension View {
    func shimmering(isActive: Bool = true) -> some View {
        modifier(JackpotShimmer(isActive: isActive))
    }
}

#if DEBUG
struct JackpotLaunchSkeleton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            JackpotLaunchSkeleton().previewDisplayName("Launch skeleton")
            JackpotLaunchSkeleton(showsBanner: false, gridRows: 4).previewDisplayName("No banner")
            JackpotLaunchSkeleton().shimmering(isActive: false)
                .previewDisplayName("No shimmer")
        }
        .preferredColorScheme(.dark)
    }
}
#endif
