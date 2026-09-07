import SwiftUI

public struct JackpotChecklistItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let isSatisfied: Bool

    public init(id: String, text: String, isSatisfied: Bool) {
        self.id = id
        self.text = text
        self.isSatisfied = isSatisfied
    }
}

public struct JackpotChecklist: View {
    private let title: String
    private let section: String
    private let items: [JackpotChecklistItem]

    @Environment(\.jackpotTheme) private var theme
    @State private var isExpanded = true

    public init(_ title: String, section: String = "Required", items: [JackpotChecklistItem]) {
        self.title = title
        self.section = section
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: .sm) {
                    ProgressView(value: satisfiedFraction)
                        .progressViewStyle(.jackpotBar(height: .xs))
                        .tint(satisfiedFraction < 1 ? theme.colors.warning : theme.colors.success)
                        .accessibilityLabel("Requirements met")

                    Text(section).jackpotTextStyle(\.sectionTitle)

                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .padding(.top, .sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(title).jackpotTextStyle(\.sectionTitle)
            }
            // The chevron follows the tint, which the theme points at the accent colour.
            .tint(theme.colors.textPrimary)
            .padding(theme.sizes.contentPadding)
            .jackpotBackground(\.fieldBackground, in: theme.sizes.fieldShape)
            .animation(.spring(response: 0.3, dampingFraction: 1), value: isExpanded)
        }
    }

    private func row(for item: JackpotChecklistItem) -> some View {
        HStack(spacing: .sm) {
            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isSatisfied ? theme.colors.accent : theme.colors.textSecondary)
                .animation(.easeOut(duration: 0.15), value: item.isSatisfied)
            Text(item.text).jackpotTextStyle(\.rowLabel)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.isSatisfied ? "Met" : "Not met")
    }

    private var satisfiedFraction: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isSatisfied).count) / Double(items.count)
    }
}
