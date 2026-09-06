import SwiftUI

/// One row in a checklist.
public struct JackpotChecklistItem: Identifiable, Equatable {
    public let id: String
    public let text: String
    public let isSatisfied: Bool

    public init(id: String, text: String, isSatisfied: Bool) {
        self.id = id
        self.text = text
        self.isSatisfied = isSatisfied
    }
}

/// An expandable panel with a progress bar and tickable rows — the "Password Validity" panel
/// from the design, generalised.
public struct JackpotChecklist: View {
    private let title: String
    private let sectionTitle: String
    private let items: [JackpotChecklistItem]

    @Environment(\.jackpotTheme) private var theme
    @State private var isExpanded = true

    public init(title: String, sectionTitle: String = "Required", items: [JackpotChecklistItem]) {
        self.title = title
        self.sectionTitle = sectionTitle
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text(title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.up").rotationEffect(.degrees(isExpanded ? 0 : 180))
                    }
                    .foregroundColor(theme.textPrimary)
                }

                if isExpanded {
                    JackpotProgressBar(progress: satisfiedFraction,
                                       tint: satisfiedFraction < 1 ? .orange : theme.success)
                        .frame(height: 6)
                    Text(sectionTitle).font(.subheadline.weight(.semibold)).foregroundColor(theme.textPrimary)
                    ForEach(items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isSatisfied ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isSatisfied ? theme.accent : theme.textSecondary)
                            Text(item.text).font(.subheadline).foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityValue(item.isSatisfied ? "Met" : "Not met")
                    }
                }
            }
            .padding(14)
            .background(theme.fieldBackground)
            .cornerRadius(theme.cornerRadius)
        }
    }

    private var satisfiedFraction: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isSatisfied).count) / Double(items.count)
    }
}
