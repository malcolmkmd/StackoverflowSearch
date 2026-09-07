#if DEBUG
import SwiftUI
import JackpotUI
import JackpotFormsDomain
import JackpotFormsData
import JackpotNetworking
import JackpotFormsUI

/// JSON-backed previews — these go through the real decoder against the captured
/// `registration.json`, so they catch a schema change that the hand-built fixtures in
/// `JackpotFormsUI` would not. This is the only target that can see both layers.
struct MockedForm_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DynamicFormView(formName: .registration) { _ in }
                .formDependencies(.mock(delay: 0))
                .previewDisplayName("Registration — from JSON")

            DynamicFormView(formName: .kitchenSink) { _ in }
                .formDependencies(.mock(delay: 0))
                .previewDisplayName("Registration fields — from JSON")

            DynamicFormView(formName: .registration) { _ in }
                .formDependencies(.mock(delay: 3600))
                .previewDisplayName("Loading")

            DynamicFormView(formName: .registration) { _ in }
                .formDependencies(.mock(delay: 0, error: APIError.transport(.notConnectedToInternet)))
                .previewDisplayName("Offline")

            DynamicFormView(formName: FormName("doesNotExist")) { _ in }
                .formDependencies(.mock(delay: 0))
                .previewDisplayName("Unknown form — 404")
        }
        .frame(height: 620)
        .background(JackpotTheme.jackpotCity.colors.surface)
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}

struct MockedSandbox_Previews: PreviewProvider {
    static var previews: some View {
        FormSandboxView.mocked()
            .preferredColorScheme(.dark)
            .previewDisplayName("Sandbox — the testing page")
    }
}
#endif
