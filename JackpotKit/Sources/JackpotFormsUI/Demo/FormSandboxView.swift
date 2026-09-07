import SwiftUI
import JackpotFormsDomain
import JackpotUI

/// The review harness: pick a form, watch it render from JSON alone, submit it, and read back
/// exactly what the callback received. Nothing here is app-specific.
public struct FormSandboxView: View {

    public struct Sample: Identifiable, Hashable {
        public let id: FormName
        public let title: String
        public init(id: FormName, title: String) {
            self.id = id
            self.title = title
        }
    }

    private let samples: [Sample]
    private let dependencies: FormDependencies

    @State private var selected: Sample
    @State private var lastSubmission: [String: String]?
    @State private var showsSubmission = false

    public init(samples: [Sample], dependencies: FormDependencies) {
        precondition(!samples.isEmpty, "FormSandboxView needs at least one sample form")
        self.samples = samples
        self.dependencies = dependencies
        _selected = State(initialValue: samples[0])
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                picker
                Divider()
                DynamicFormView(formName: selected.id) { submission in
                    // Deliberately not posting anywhere: the sandbox proves the callback
                    // contract, not the registration endpoint.
                    lastSubmission = submission.stringValues
                    showsSubmission = true
                }
                .id(selected.id)                 // rebuild the engine when the form changes
                .formDependencies(dependencies)
            }
            .navigationTitle("Form Sandbox")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showsSubmission) {
                SubmissionResultView(values: lastSubmission ?? [:])
            }
        }
        .navigationViewStyle(.stack)
    }

    private var picker: some View {
        Picker("Form", selection: $selected) {
            ForEach(samples) { sample in
                Text(sample.title).tag(sample)
            }
        }
        .pickerStyle(.segmented)
        .padding(JackpotSpacing.sm)
    }
}

struct SubmissionResultView: View {
    let values: [String: String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(values.keys.sorted(), id: \.self) { key in
                VStack(alignment: .leading, spacing: 2) {
                    Text(key).font(.caption).foregroundColor(.secondary)
                    Text(values[key]?.isEmpty == false ? values[key]! : "—")
                        .font(.body.monospaced())
                }
            }
            .navigationTitle("Submitted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

#if DEBUG
struct FormSandboxView_Previews: PreviewProvider {
    /// Serves the hand-built fixtures, so the sandbox previews without the bundle.
    private struct FixtureRepository: FormRepository {
        func form(named name: FormName) async throws -> FormSchema {
            try await Task.sleep(nanoseconds: 300_000_000)
            return FormPreview.registration
        }

        func submitForm(_ submission: FormSubmission) async throws -> FormSubmitResult { FormSubmitResult() }
    }

    static var previews: some View {
        FormSandboxView(
            samples: [.init(id: .registration, title: "Registration")],
            dependencies: FormDependencies(repository: FixtureRepository(),
                                           localizer: ComposedKeyLocalizer.jpcRegistration)
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Sandbox")
    }
}
#endif
