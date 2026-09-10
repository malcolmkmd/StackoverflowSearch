import SwiftUI

public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .sm) {
            content
        }
        .padding(.m)
        .frame(width: 390)
        .jackpotTheme(.jackpotCity)
        .jackpotBackground(\.background)
    }
}

// MARK: - Component gallery

#if DEBUG
struct JackpotUI_Previews: PreviewProvider {
    struct Harness: View {
        @State private var mobile = ""
        @State private var email = ""
        @State private var secret = "Passwo1"
        @State private var promotions = false
        @State private var agreed = true
        @State private var income: String? = nil
        @State private var dateOfBirth: Date? = nil

        var body: some View {
            ScrollView {
                JackpotPreviewPanel("Gallery") {
                    JackpotTextField("Mobile Number", text: $mobile, kind: .phoneNumber, prefix: "+27")

                    JackpotTextField("Email", text: $email, kind: .email)

                    JackpotTextField("Password", text: $secret, kind: .newPassword)
                        .jackpotFieldError("Password must be 8–20 characters")

                    JackpotChecklist("Password Validity", items: [
                        .init(id: "min", text: "Minimum of 8 characters", isSatisfied: false),
                        .init(id: "max", text: "Maximum of 20 characters", isSatisfied: true),
                    ])

                    JackpotDropdown("Source Of Income", selection: $income, options: [
                        .init(id: "salary", label: "Salary or Wages"),
                        .init(id: "pension", label: "Pension or Grant"),
                    ])
                    .jackpotFieldError("Please choose one")

                    JackpotDateField("Date Of Birth", selection: $dateOfBirth)

                    Toggle("Send Jackpot City Promotions to me", isOn: $promotions)
                        .toggleStyle(.jackpotCheckbox)
                    Toggle("I am over 18 years of age & I accept the Terms & Conditions", isOn: $agreed)
                        .toggleStyle(.jackpotCheckbox)

                    ProgressView(value: 0.45).progressViewStyle(.jackpotBar)

                    Button("Next") {}.buttonStyle(.jackpot).disabled(true)
                    Button("Sign Up") {}.buttonStyle(.jackpot).jackpotLoading()
                    Button("Previous") {}.buttonStyle(.jackpot(.secondary))
                }
            }
            .jackpotTheme(.jackpotCity)
            .jackpotBackground(\.background)
        }
    }

    struct Shell: View {
        @State private var mobile = ""
        @State private var email = ""

        var body: some View {
            JackpotPanel("Sign Up", onClose: {}) {
                VStack(spacing: .sm) {
                    JackpotTextField("Mobile Number", text: $mobile, kind: .phoneNumber, prefix: "+27")
                    JackpotTextField("Email", text: $email, kind: .email)
                }
                .padding(.m)
            } footer: {
                VStack(spacing: .sm) {
                    JackpotLinkRow("Already have an account?", link: "Login") {}
                    Button("Next") {}.buttonStyle(.jackpot).disabled(true)
                }
            }
            .padding(.m)
            .frame(width: 390)
            .jackpotTheme(.jackpotCity)
            .jackpotBackground(\.background)
        }
    }

    static var previews: some View {
        Group {
            Harness().preferredColorScheme(.dark).previewDisplayName("Gallery — dark")
            Harness().preferredColorScheme(.light).previewDisplayName("Gallery — light")
            Shell().preferredColorScheme(.dark).previewDisplayName("Sheet shell — dark")
            Shell().preferredColorScheme(.light).previewDisplayName("Sheet shell — light")
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
