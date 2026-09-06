#if DEBUG
import SwiftUI

/// Puts a component on the panel's dark surface at a realistic width, so previews look like
/// the real thing rather than a white sheet. Public so feature packages can use it too.
public struct JackpotPreviewPanel<Content: View>: View {
    private let title: String?
    private let content: Content

    public init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.caption).foregroundColor(.white.opacity(0.5)) }
            content
        }
        .padding(16)
        .frame(width: 390)
        .background(JackpotTheme.jackpotCity.surface)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Component gallery

struct JackpotUI_Previews: PreviewProvider {
    struct Harness: View {
        @State var text = ""
        @State var secret = "Passwo1"
        @State var isOn = false
        @State var agreed = true
        @State var choice: String? = nil
        @State var radio: String? = "email"
        @State var date: Date? = nil

        var body: some View {
            ScrollView {
                JackpotPreviewPanel("Gallery") {
                    JackpotLabeledField(label: "Mobile", error: nil) {
                        JackpotTextField("Enter Mobile Number", text: $text, prefix: "+27", keyboard: .numberPad)
                    }
                    JackpotLabeledField(error: "Password must be 8–20 characters") {
                        JackpotTextField("Password", text: $secret, isSecure: true, isInvalid: true)
                    }
                    JackpotChecklist(title: "Password Validity", items: [
                        .init(id: "min", text: "Minimum of 8 characters", isSatisfied: false),
                        .init(id: "max", text: "Maximum of 20 characters", isSatisfied: true),
                    ])
                    JackpotDropdown("Enter Source Of Income", selection: $choice, options: [
                        .init(id: "salary", label: "Salary or Wages"), .init(id: "pension", label: "Pension or Grant"),
                    ], isInvalid: true)
                    JackpotDateField("Enter Date Of Birth", title: "Date of Birth", date: $date)
                    JackpotRadioGroup(selection: $radio, options: [
                        .init(id: "sms", label: "SMS"), .init(id: "email", label: "Email"),
                    ])
                    JackpotCheckbox("Send Jackpot City Promotions to me", isOn: $isOn)
                    JackpotCheckbox("I am over 18 years of age & I accept the Terms & Conditions", isOn: $agreed)
                    JackpotToggleRow("Keep me logged in", isOn: $isOn)
                    JackpotProgressBar(progress: 0.45)
                    HStack(spacing: 10) {
                        JackpotSelectableCard(isSelected: true, action: {}) { Text("100% Deposit Match").foregroundColor(.white) }
                        JackpotSelectableCard(isSelected: false, action: {}) { Text("50 Free Spins").foregroundColor(.white) }
                    }
                    .jackpotLocked(true, message: "Complete your registration above to unlock your Welcome offer selection")
                    JackpotButton("Next", isEnabled: false) {}
                    JackpotButton("Sign Up", isLoading: true) {}
                    JackpotButton("Previous", kind: .secondary) {}
                }
            }
            .background(JackpotTheme.jackpotCity.surface)
        }
    }

    static var previews: some View {
        Group {
            Harness().previewDisplayName("Gallery")
            JackpotPreviewPanel("Skeleton") { JackpotSkeleton() }.previewDisplayName("Skeleton")
            JackpotPreviewPanel("Error") { JackpotErrorView(message: "The network connection was lost.") {} }
                .previewDisplayName("Error")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
