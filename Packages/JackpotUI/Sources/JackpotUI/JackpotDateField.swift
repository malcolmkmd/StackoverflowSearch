import SwiftUI

/// A field that opens a graphical date picker in a sheet.
public struct JackpotDateField: View {
    @Binding private var date: Date?
    private let placeholder: String
    private let title: String
    private let range: PartialRangeThrough<Date>
    private let isInvalid: Bool
    private let isDisabled: Bool
    private let onCommit: () -> Void

    @Environment(\.jackpotTheme) private var theme
    @State private var isPresented = false

    public init(_ placeholder: String,
                title: String,
                date: Binding<Date?>,
                in range: PartialRangeThrough<Date> = ...Date(),
                isInvalid: Bool = false,
                isDisabled: Bool = false,
                onCommit: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self.title = title
        self._date = date
        self.range = range
        self.isInvalid = isInvalid
        self.isDisabled = isDisabled
        self.onCommit = onCommit
    }

    public var body: some View {
        Button { isPresented = true } label: {
            HStack {
                Text(date.map(Self.display.string(from:)) ?? placeholder)
                    .foregroundColor(date == nil ? theme.textSecondary : theme.textPrimary)
                Spacer()
                Image(systemName: "calendar").foregroundColor(theme.textPrimary)
            }
            .padding(.horizontal, 14)
            .frame(height: theme.controlHeight)
            .jackpotFieldBorder(isInvalid: isInvalid)
        }
        .disabled(isDisabled)
        .sheet(isPresented: $isPresented) { sheet }
    }

    private var sheet: some View {
        VStack(spacing: 16) {
            Text(title).font(.headline).padding(.top, 20)
            DatePicker("",
                       selection: Binding(get: { date ?? range.upperBound }, set: { date = $0 }),
                       in: range,
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal)
            JackpotButton("Done") {
                if date == nil { date = range.upperBound }
                onCommit()
                isPresented = false
            }
            .padding([.horizontal, .bottom], 16)
        }
    }

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}
