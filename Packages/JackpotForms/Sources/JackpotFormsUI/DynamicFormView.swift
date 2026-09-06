import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// The single component the ticket asks for.
///
///     DynamicFormView(formName: .registration) { submission in
///         try await api.register(submission.stringValues)
///     }
///
/// Two arguments: the form name used to fetch the schema, and the callback that receives the
/// collected data. Everything else arrives through the environment (`.formDependencies(_:)`,
/// `.jackpotTheme(_:)`) so no dependency is hidden in a global.
public struct DynamicFormView: View {

    public typealias SubmitHandler = (FormSubmission) async throws -> Void

    private let formName: FormName
    private let onSubmit: SubmitHandler

    @Environment(\.formDependencies) private var dependencies
    @Environment(\.jackpotTheme) private var theme
    @StateObject private var model: DynamicFormModel
    @State private var hasLoaded = false

    /// The two-argument form. Dependencies come from the environment.
    public init(formName: FormName, onSubmit: @escaping SubmitHandler) {
        self.formName = formName
        self.onSubmit = onSubmit
        // @StateObject cannot read @Environment in init, so a placeholder is swapped for the
        // environment's dependencies on first appearance.
        _model = StateObject(wrappedValue: DynamicFormModel(
            formName: formName,
            dependencies: FormDependencies(repository: UnavailableFormRepository()),
            isConfigured: false
        ))
    }

    /// Explicit-dependency form, for previews and tests that don't want an environment.
    public init(formName: FormName, dependencies: FormDependencies, onSubmit: @escaping SubmitHandler) {
        self.formName = formName
        self.onSubmit = onSubmit
        _model = StateObject(wrappedValue: DynamicFormModel(formName: formName, dependencies: dependencies))
    }

    public var body: some View {
        DynamicFormBody(model: model, onSubmit: onSubmit)
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                model.configureIfNeeded(with: dependencies)
                model.load()
            }
    }
}

/// The rendered form for a given model. Separate from `DynamicFormView` so previews can drive
/// it from a seeded model without a fetch.
struct DynamicFormBody: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler
    @Environment(\.jackpotTheme) private var theme

    var body: some View {
        switch model.viewState {
        case .loading:
            JackpotSkeleton().padding(16)

        case .failed(let message):
            JackpotErrorView(title: "Couldn't load this form", message: message) { model.load() }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    JackpotProgressBar(progress: model.progress)
                        .padding(.horizontal, 16).padding(.top, 12)
                        .accessibilityLabel("Form progress")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacing) {
                        if let section = model.currentSection {
                            ForEach(section.rows) { row in FormRowView(row: row, model: model) }
                        }
                        if let error = model.submitError {
                            Text(error).font(.footnote).foregroundColor(theme.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        #if DEBUG
                        if !model.unsupportedFields.isEmpty {
                            Text("Unsupported field types skipped: \(model.unsupportedFields.joined(separator: ", "))")
                                .font(.caption2).foregroundColor(.orange)
                        }
                        #endif
                    }
                    .padding(16)
                }

                FormNavigationBar(model: model, onSubmit: onSubmit)
                    .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(theme.surface)
            .animation(.easeOut(duration: 0.2), value: model.sectionIndex)
        }
    }
}

/// Fields sharing a `rowNumber` render side by side; a single field fills the row. This is
/// what makes the "+27 | Mobile Number" pairing fall out of the schema rather than being
/// special-cased.
struct FormRowView: View {
    let row: FormRow
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        let visible = row.fields.filter { $0.isVisible }
        if visible.count == 1 {
            FieldRenderer(field: visible[0], model: model)
        } else if !visible.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

struct FormNavigationBar: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler

    var body: some View {
        HStack(spacing: 12) {
            if !model.isFirstSection {
                JackpotButton("Previous", kind: .secondary) { model.goBack() }
            }
            if model.isLastSection {
                JackpotButton("Sign Up", isEnabled: model.isFormValid, isLoading: model.isSubmitting) {
                    Task { await model.submit(onSubmit) }
                }
            } else {
                JackpotButton("Next", isEnabled: model.isCurrentSectionValid) { model.advance() }
            }
        }
    }
}


// MARK: - Previews

#if DEBUG
struct DynamicFormView_Previews: PreviewProvider {
    private struct Harness: View {
        let model: DynamicFormModel
        var body: some View {
            DynamicFormBody(model: model) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.surface)
                .preferredColorScheme(.dark)
        }
    }

    static var previews: some View {
        Group {
            Harness(model: .preview(schema: FormPreview.registration))
                .previewDisplayName("Section 1 — empty")
            Harness(model: .preview(schema: FormPreview.registration, values: FormPreview.validSectionOne))
                .previewDisplayName("Section 1 — valid, Next enabled")
            Harness(model: .preview(schema: FormPreview.registration,
                                    touched: ["username", "password", "firstname", "lastname", "email"]))
                .previewDisplayName("Section 1 — all errors shown")
            Harness(model: .preview(schema: FormPreview.registration, values: FormPreview.validSectionOne, sectionIndex: 1))
                .previewDisplayName("Section 2 — FICA")
            Harness(model: .preview(schema: FormPreview.registration, values: FormPreview.validSectionOne,
                                    touched: ["idNumber", "dateOfBirth", "sourceOfFunds", "terms"], sectionIndex: 1))
                .previewDisplayName("Section 2 — all errors shown")
            Harness(model: .previewLoading()).previewDisplayName("Loading")
            Harness(model: .previewFailed()).previewDisplayName("Failed")
            Harness(model: .preview(schema: FormPreview.registration))
                .environment(\.sizeCategory, .accessibilityLarge)
                .previewDisplayName("Accessibility — XL text")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
