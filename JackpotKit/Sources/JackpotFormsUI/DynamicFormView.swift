import SwiftUI
import JackpotUI
import JackpotFormsDomain

/// A whole form, from one name and one callback.
///
///     DynamicFormView(formName: .registration) { submission in
///         try await api.register(submission.stringValues)
///     }
///
/// Everything else arrives through the environment (`.formDependencies(_:)`,
/// `.jackpotTheme(_:)`), so no dependency is hidden in a global.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedField: String?
    @State private var isAdvancing = true

    var body: some View {
        switch model.viewState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityLabel("Loading form")

        case .failed(let message):
            JackpotErrorView(message, title: "Couldn't load this form")
                .onRetry { model.load() }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.jackpotBar)
                        .padding(.horizontal, JackpotSpacing.m).padding(.top, JackpotSpacing.sm)
                        .accessibilityLabel("Form progress")
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: theme.sizes.spacing) {
                        if let section = model.currentSection {
                            ForEach(section.rows) { row in FormRowView(row: row, model: model) }
                        }
                        if let error = model.submitError {
                            Text(error).font(.footnote).jackpotForegroundStyle(\.error)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        #if DEBUG
                        if !model.unsupportedFields.isEmpty {
                            Text("Unsupported field types skipped: \(model.unsupportedFields.joined(separator: ", "))")
                                .font(.caption2).foregroundColor(.orange)
                        }
                        #endif
                    }
                    .padding(JackpotSpacing.m)
                    // New identity per section is what lets the transition run at all; the
                    // nav bar and progress bar sit outside it so they don't slide too.
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }

                FormNavigationBar(model: model,
                                  onSubmit: onSubmit,
                                  advance: advance,
                                  goBack: goBack)
                    .padding(.horizontal, JackpotSpacing.m).padding(.vertical, JackpotSpacing.sm)
            }
            .jackpotBackground(\.surface)
            .jackpotFocusedField($focusedField)
            // Validate before moving focus, so the error and the new focus land in one update
            // rather than the error arriving a render after the keyboard has moved on.
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(identifiedBy: current)
                focusedField = model.fieldAfter(current)
            }
            // Covers section changes that don't come from the nav bar.
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    // MARK: Paging

    // Direction has to be set before the index changes, not in an onChange afterwards —
    // the transition is resolved in the same update that moves the section.
    private func advance() {
        isAdvancing = true
        focusedField = nil
        withAnimation(pagingAnimation) { _ = model.advance() }
    }

    private func goBack() {
        isAdvancing = false
        focusedField = nil
        withAnimation(pagingAnimation) { model.goBack() }
    }

    /// Offset rather than a full `.move`, so the outgoing and incoming sections don't drag
    /// the scroll view's content width around mid-flight.
    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = isAdvancing ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }

    private var pagingAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2)
                     : .spring(response: 0.42, dampingFraction: 0.86)
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
            HStack(alignment: .top, spacing: JackpotSpacing.s) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

struct FormNavigationBar: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler
    let advance: () -> Void
    let goBack: () -> Void

    var body: some View {
        HStack(spacing: JackpotSpacing.sm) {
            if !model.isFirstSection {
                Button("Previous", action: goBack)
                    .buttonStyle(.jackpot(.secondary))
            }
            if model.isLastSection {
                Button("Sign Up") { Task { await model.submit(onSubmit) } }
                    .buttonStyle(.jackpot)
                    .disabled(!model.isFormValid)
                    .jackpotLoading(model.isSubmitting)
            } else {
                Button("Next", action: advance)
                    .buttonStyle(.jackpot)
                    .disabled(!model.isCurrentSectionValid)
            }
        }
    }
}


// MARK: - Previews

#if DEBUG
struct DynamicFormView_Previews: PreviewProvider {
    private struct Harness: View {
        let model: DynamicFormModel
        var scheme: ColorScheme = .dark
        var body: some View {
            DynamicFormBody(model: model) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.surface)
                .preferredColorScheme(scheme)
        }
    }

    static var previews: some View {
        Group {
            Harness(model: .preview(schema: FormPreview.registration))
                .previewDisplayName("Section 1 — empty")
            Harness(model: .preview(schema: FormPreview.registration), scheme: .light)
                .previewDisplayName("Section 1 — light")
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
