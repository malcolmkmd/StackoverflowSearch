import SwiftUI
import JackpotUI

/// A whole form, from one name, one set of dependencies and one callback: the pages with the
/// navigation bar beneath them.
///
///     DynamicFormView(formName: .registration, dependencies: .mock()) { submission in
///         try await api.register(submission.stringValues)
///     }
///
/// A host that wants the navigation somewhere else — registration puts Next in its panel's
/// footer beside the login row — owns a `DynamicFormModel` itself and places
/// `DynamicFormContent` and `FormNavigationBar` where the design says.
public struct DynamicFormView: View {

    public typealias SubmitHandler = @MainActor (FormSubmission) async throws -> Void

    private let onSubmit: SubmitHandler
    @StateObject private var model: DynamicFormModel

    public init(formName: FormName, dependencies: FormDependencies, onSubmit: @escaping SubmitHandler) {
        self.onSubmit = onSubmit
        _model = StateObject(wrappedValue: DynamicFormModel(formName: formName, dependencies: dependencies))
    }

    public var body: some View {
        DynamicFormBody(model: model, onSubmit: onSubmit)
            .task { await model.load() }
    }
}

/// Pages and navigation stacked, for a given model: what `DynamicFormView` renders, and what
/// the previews drive from a seeded model without a fetch.
struct DynamicFormBody: View {
    @ObservedObject var model: DynamicFormModel
    let onSubmit: DynamicFormView.SubmitHandler

    var body: some View {
        VStack(spacing: 0) {
            DynamicFormContent(model: model)
            FormNavigationBar(model: model, onSubmit: onSubmit)
                .padding(.horizontal, .m).padding(.vertical, .sm)
        }
        .jackpotBackground(\.background)
    }
}

/// The form's pages: the progress bar, the current section's rows and any submit error, with
/// the loading and failure states in their place. Moving between pages is `FormNavigationBar`.
public struct DynamicFormContent: View {
    @ObservedObject private var model: DynamicFormModel

    @Environment(\.jackpotTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedField: String?

    public init(model: DynamicFormModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    public var body: some View {
        switch model.viewState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 220)
                .accessibilityLabel("Loading form")

        case .failed(let message):
            JackpotErrorView(message, title: "Couldn't load this form")
                .onRetry { Task { await model.load() } }

        case .loaded:
            VStack(spacing: 0) {
                if model.sections.count > 1 {
                    ProgressView(value: model.progress)
                        .progressViewStyle(.jackpotBar)
                        .padding(.horizontal, .m).padding(.top, .sm)
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
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        #endif
                    }
                    .padding(.m)
                    // New identity per section is what lets the transition run at all; the
                    // progress bar sits outside it so it doesn't slide too.
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }
            }
            .jackpotFocusedField($focusedField)
            // Validate before moving focus, so the error and the new focus land in one update
            // rather than the error arriving a render after the keyboard has moved on.
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(identifiedBy: current)
                focusedField = model.fieldAfter(current)
            }
            // A page move dismisses the keyboard, wherever the move came from.
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    /// Offset rather than a full `.move`, so the outgoing and incoming sections don't drag
    /// the scroll view's content width around mid-flight. The direction comes from the model,
    /// which sets it in the same update that moves the section.
    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = model.pagingDirection == .forward ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }
}

/// Fields sharing a `rowNumber` render side by side; a single field fills the row.
struct FormRowView: View {
    let row: FormRow
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        let visible = row.fields.filter(\.isVisible)
        if visible.count == 1 {
            FieldRenderer(field: visible[0], model: model)
        } else if !visible.isEmpty {
            HStack(alignment: .top, spacing: .s) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

/// Previous / Next / Sign Up. Paging is not a field: the schema describes sections, and this
/// bar is how the user moves between them. Nothing renders until the form has loaded. Place it
/// under `DynamicFormContent`, or wherever the design puts it — registration puts it in the
/// panel's footer beside the login row.
public struct FormNavigationBar: View {
    @ObservedObject private var model: DynamicFormModel
    private let onSubmit: DynamicFormView.SubmitHandler

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DynamicFormModel, onSubmit: @escaping DynamicFormView.SubmitHandler) {
        _model = ObservedObject(wrappedValue: model)
        self.onSubmit = onSubmit
    }

    public var body: some View {
        if model.form != nil {
            HStack(spacing: .sm) {
                if !model.isFirstSection {
                    Button("Previous") { withAnimation(pagingAnimation) { model.goBack() } }
                        .buttonStyle(.jackpot(.secondary))
                }
                if model.isLastSection {
                    Button("Sign Up") { Task { await model.submit(onSubmit) } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isFormValid)
                        .jackpotLoading(model.isSubmitting)
                } else {
                    Button("Next") { withAnimation(pagingAnimation) { _ = model.advance() } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isCurrentSectionValid)
                }
            }
        }
    }

    private var pagingAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.2)
                     : .spring(response: 0.42, dampingFraction: 0.86)
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
                .background(JackpotTheme.jackpotCity.colors.background)
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

            // Through the real loader, so a schema change in the JSON shows up here.
            DynamicFormView(formName: .registration, dependencies: .mock(delay: 0)) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Registration — from JSON")
            DynamicFormView(formName: .registration, dependencies: .mock(delay: 0, error: FormLoadError.offline)) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Offline")
            DynamicFormView(formName: FormName("doesNotExist"), dependencies: .mock(delay: 0)) { _ in }
                .frame(height: 620)
                .background(JackpotTheme.jackpotCity.colors.background)
                .preferredColorScheme(.dark)
                .previewDisplayName("Unknown form — 404")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
