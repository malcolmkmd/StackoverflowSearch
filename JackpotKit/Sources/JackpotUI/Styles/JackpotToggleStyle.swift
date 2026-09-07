import SwiftUI

public struct JackpotToggleStyle: ToggleStyle {
    public enum Appearance: Hashable, Sendable {
        case checkbox
        case `switch`
    }

    private let appearance: Appearance

    public init(_ appearance: Appearance = .checkbox) {
        self.appearance = appearance
    }

    public func makeBody(configuration: Configuration) -> some View {
        ToggleBody(appearance: appearance, configuration: configuration)
    }

    private struct ToggleBody: View {
        let appearance: Appearance
        let configuration: ToggleStyleConfiguration

        @Environment(\.jackpotTheme) private var theme
        @Environment(\.jackpotValidationMessage) private var validationMessage

        var body: some View {
            switch appearance {
            case .checkbox: checkbox
            case .switch:   platformSwitch
            }
        }

        private var checkbox: some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(alignment: .top, spacing: theme.sizes.spacing) {
                    Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                        .font(.title3)
                        .foregroundStyle(boxColor)
                        .frame(width: .l, height: .l)
                        .animation(.easeOut(duration: 0.15), value: configuration.isOn)
                    configuration.label
                        .jackpotTextStyle(\.rowLabel)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: theme.sizes.minimumHitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityRepresentation {
                // The explicit style stops the stand-in resolving back to this one.
                Toggle(isOn: configuration.$isOn) { configuration.label }
                    .toggleStyle(.switch)
            }
        }

        private var platformSwitch: some View {
            Toggle(configuration)
                .toggleStyle(.switch)
                .jackpotTextStyle(\.rowLabel)
        }

        private var boxColor: Color {
            if configuration.isOn { return theme.colors.accent }
            return validationMessage == nil ? theme.colors.textSecondary : theme.colors.fieldBorderInvalid
        }
    }
}

public extension ToggleStyle where Self == JackpotToggleStyle {
    static var jackpotCheckbox: JackpotToggleStyle { JackpotToggleStyle(.checkbox) }
    static var jackpotSwitch: JackpotToggleStyle { JackpotToggleStyle(.switch) }
}
