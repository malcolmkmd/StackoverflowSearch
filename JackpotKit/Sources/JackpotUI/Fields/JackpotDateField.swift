import SwiftUI

public struct JackpotDateField: View {
    @Binding private var selection: Date?
    private let placeholder: String
    private let range: PartialRangeThrough<Date>

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.jackpotFieldLabel) private var fieldLabel
    @State private var isPresented = false

    public init(_ placeholder: String,
                selection: Binding<Date?>,
                in range: PartialRangeThrough<Date> = ...Date()) {
        self.placeholder = placeholder
        self._selection = selection
        self.range = range
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack {
                Text(displayedValue)
                    .jackpotForegroundStyle(valueColor)
                Spacer()
                Image(systemName: "calendar").jackpotForegroundStyle(\.textPrimary)
            }
            .jackpotFont(\.fieldText)
            .padding(.horizontal, theme.metrics.contentPadding)
            .frame(height: theme.metrics.controlHeight)
            .jackpotFieldBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fieldLabel ?? placeholder)
        .accessibilityValue(selection == nil ? "None" : displayedValue)
        .sheet(isPresented: $isPresented) { sheet }
    }

    private var sheet: some View {
        ZStack {
            theme.colors.surface.ignoresSafeArea()

            VStack(spacing: theme.metrics.spacing) {
                Text(fieldLabel ?? placeholder)
                    .jackpotTextStyle(\.button)
                    .padding(.top, 20)

                DatePicker("",
                           selection: Binding(get: { selection ?? range.upperBound },
                                              set: { selection = $0 }),
                           in: range,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal)

                Button("Done") {
                    // Confirming without dragging still counts as a choice, otherwise the
                    // field silently stays empty.
                    if selection == nil { selection = range.upperBound }
                    isPresented = false
                }
                .buttonStyle(.jackpot)
                .padding([.horizontal, .bottom], 16)
            }
        }
    }

    private var displayedValue: String {
        guard let selection else { return placeholder }
        return selection.formatted(date: .abbreviated, time: .omitted)
    }

    private var valueColor: KeyPath<JackpotColors, Color> {
        selection == nil ? \.textSecondary : \.textPrimary
    }
}
