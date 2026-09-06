#if DEBUG
import SwiftUI

public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.caption).jackpotForegroundStyle(\.textSecondary)
            }
            content
        }
        .padding(16)
        .frame(width: 390)
        .jackpotTheme(.jackpotCity)
        .jackpotBackground(\.surface)
    }
}

// MARK: - Component gallery

struct JackpotUI_Previews: PreviewProvider {
    struct Harness: View {
        @State private var mobile = ""
        @State private var email = ""
        @State private var secret = "Passwo1"
        @State private var touched = false
        @State private var promotions = false
        @State private var agreed = true
        @State private var persistLogin = false
        @State private var income: String? = nil
        @State private var contactMethod: String? = "email"
        @State private var dateOfBirth: Date? = nil
        @State private var offer: String? = "depositMatch"

        var body: some View {
            ScrollView {
                JackpotPreviewPanel("Gallery") {
                    JackpotLabeledField("Mobile") {
                        JackpotTextField("Enter Mobile Number", text: $mobile)
                            .onEditingEnded { touched = true }
                            .jackpotField(.phoneNumber)
                            .jackpotFieldPrefix("+27")
                    }

                    JackpotLabeledField("Email") {
                        JackpotTextField("Enter Email Address", text: $email)
                            .jackpotField(.email)
                    }

                    JackpotLabeledField(error: "Password must be 8–20 characters") {
                        JackpotTextField("Password", text: $secret)
                            .jackpotField(.newPassword)
                    }

                    JackpotChecklist("Password Validity", items: [
                        .init(id: "min", text: "Minimum of 8 characters", isSatisfied: false),
                        .init(id: "max", text: "Maximum of 20 characters", isSatisfied: true),
                    ])

                    JackpotLabeledField("Source Of Income", error: "Please choose one") {
                        JackpotDropdown("Enter Source Of Income", selection: $income, options: [
                            .init(id: "salary", label: "Salary or Wages"),
                            .init(id: "pension", label: "Pension or Grant"),
                        ])
                    }

                    JackpotLabeledField("Date Of Birth") {
                        JackpotDateField("Enter Date Of Birth", selection: $dateOfBirth)
                    }

                    JackpotLabeledField("Preferred Contact") {
                        JackpotRadioGroup(selection: $contactMethod, options: [
                            .init(id: "sms", label: "SMS"),
                            .init(id: "email", label: "Email"),
                        ])
                    }

                    Toggle("Send Jackpot City Promotions to me", isOn: $promotions)
                        .toggleStyle(.jackpotCheckbox)
                    Toggle("I am over 18 years of age & I accept the Terms & Conditions", isOn: $agreed)
                        .toggleStyle(.jackpotCheckbox)
                    Toggle("Keep me logged in", isOn: $persistLogin)
                        .toggleStyle(.jackpotSwitch)

                    ProgressView(value: 0.45).progressViewStyle(.jackpotBar)

                    HStack(spacing: 10) {
                        offerCard("100% Deposit Match", id: "depositMatch")
                        offerCard("50 Free Spins", id: "freeSpins")
                    }
                    .jackpotLocked(true, message: "Complete your registration above to unlock your Welcome offer selection")

                    Button("Next") {}.buttonStyle(.jackpot).disabled(true)
                    Button("Sign Up") {}.buttonStyle(.jackpot).jackpotLoading()
                    Button("Previous") {}.buttonStyle(.jackpot(.secondary))
                    Button("Skip for now") {}.buttonStyle(.jackpot(.tertiary))
                }
            }
            .jackpotTheme(.jackpotCity)
            .jackpotBackground(\.surface)
        }

        private func offerCard(_ label: String, id: String) -> some View {
            Button { offer = id } label: {
                Text(label).jackpotTextStyle(\.button).multilineTextAlignment(.center)
            }
            .buttonStyle(.jackpotCard)
            .jackpotSelected(offer == id)
        }
    }

    static var previews: some View {
        Group {
            Harness().preferredColorScheme(.dark).previewDisplayName("Gallery — dark")
            Harness().preferredColorScheme(.light).previewDisplayName("Gallery — light")
            JackpotPreviewPanel("Error") {
                JackpotErrorView("The network connection was lost.").onRetry {}
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Error — dark")
            JackpotPreviewPanel("Error") {
                JackpotErrorView("The network connection was lost.").onRetry {}
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Error — light")
            Harness()
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("Gallery — XL text")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
