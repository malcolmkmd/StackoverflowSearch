import SwiftUI

public struct JackpotDateField: View {
    @Binding private var selection: Date?
    private let title: String
    private let range: PartialRangeThrough<Date>

    @Environment(\.jackpotTheme) private var theme
    @State private var isPresented = false

    /// - Parameter title: the in-field label. It floats once a date is chosen and names the
    ///   picker sheet.
    public init(_ title: String,
                selection: Binding<Date?>,
                in range: PartialRangeThrough<Date> = ...Date()) {
        self.title = title
        self._selection = selection
        self.range = range
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 0) {
                JackpotFloatingField(title, isFloating: selection != nil) {
                    if let selection {
                        Text(Self.formatted(selection)).jackpotTextStyle(\.fieldText)
                    }
                }
                Image(systemName: "calendar")
                    .jackpotForegroundStyle(\.textPrimary)
                    .padding(.trailing, theme.sizes.contentPadding)
            }
            .jackpotFieldBackground()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selection.map(Self.formatted) ?? "None")
        .sheet(isPresented: $isPresented) {
            if #available(iOS 16.0, *) {
                sheet
                    .presentationDetents([.height(sheetHeight)])
                    .presentationDragIndicator(.visible)
            } else {
                sheet
            }
        }
    }

    /// Wheel plus title and button. Before iOS 16 there are no detents, so the sheet is full
    /// height and the spacer pins the button to the bottom instead.
    private var sheetHeight: CGFloat { wheelHeight + 160 }

    private var wheelHeight: CGFloat { 216 }

    private var sheet: some View {
        ZStack {
            // A presented sheet is a shell, so it draws on `surface` like a header band would.
            theme.colors.surface.ignoresSafeArea()

            VStack(spacing: theme.sizes.spacing) {
                Text(title)
                    .jackpotTextStyle(\.button)
                    .padding(.top, .lm)

                DatePicker("",
                           selection: Binding(get: { selection ?? range.upperBound },
                                              set: { selection = $0 }),
                           in: range,
                           displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: wheelHeight)
                    .padding(.horizontal)

                Spacer(minLength: 0)

                Button("Done") {
                    // Confirming without dragging still counts as a choice, otherwise the
                    // field silently stays empty.
                    if selection == nil { selection = range.upperBound }
                    isPresented = false
                }
                .buttonStyle(.jackpot)
                .padding([.horizontal, .bottom], .m)
            }
        }
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
