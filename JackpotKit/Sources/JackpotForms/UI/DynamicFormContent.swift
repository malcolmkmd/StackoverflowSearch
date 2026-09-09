import SwiftUI
import JackpotUI

/// The pages: progress, the current section's rows, the submit error, and the loading and failure states.
/// The host owns the `DynamicFormModel` and places `FormNavigationBar` wherever the design wants it.
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
                    }
                    .padding(.m)
                    // A new identity per section is what lets the transition run.
                    .id(model.sectionIndex)
                    .transition(sectionTransition)
                }
            }
            .jackpotFocusedField($focusedField)
            // Validate before moving focus, so the error and the new focus land in one update.
            .onSubmit {
                guard let current = focusedField else { return }
                model.markTouched(current)
                focusedField = model.fieldAfter(current)
            }
            .onChange(of: model.sectionIndex) { _ in focusedField = nil }
        }
    }

    /// Offset rather than `.move`, so the sections don't drag the scroll width around mid-flight.
    private var sectionTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let travel: CGFloat = model.pagingDirection == .forward ? 60 : -60
        return .asymmetric(insertion: .offset(x: travel).combined(with: .opacity),
                           removal: .offset(x: -travel).combined(with: .opacity))
    }
}

/// Fields sharing a `rowNumber` render side by side.
struct FormRowView: View {
    let row: FormRow
    @ObservedObject var model: DynamicFormModel

    var body: some View {
        // An unknown type stays off the stack: even empty, the error row would take a spacing slot.
        let visible = row.fields.filter { field in
            if case .unknown = field.type { return false }
            return field.isVisible
        }
        if !visible.isEmpty {
            HStack(alignment: .top, spacing: .s) {
                ForEach(visible) { FieldRenderer(field: $0, model: model) }
            }
        }
    }
}

/// Previous / Next / Sign Up. Renders nothing until the form has loaded; `onComplete` receives what the repository returned.
public struct FormNavigationBar: View {
    @ObservedObject private var model: DynamicFormModel
    private let onComplete: (FormSubmitResult) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: DynamicFormModel, onComplete: @escaping (FormSubmitResult) -> Void) {
        _model = ObservedObject(wrappedValue: model)
        self.onComplete = onComplete
    }

    public var body: some View {
        if model.form != nil {
            HStack(spacing: .sm) {
                if !model.isFirstSection {
                    Button("Previous") { withAnimation(pagingAnimation) { model.goBack() } }
                        .buttonStyle(.jackpot(.secondary))
                }
                if model.isLastSection {
                    Button("Sign Up") { Task { if let result = await model.submit() { onComplete(result) } } }
                        .buttonStyle(.jackpot)
                        .disabled(!model.isFormValid)
                        .jackpotLoading(model.isSubmitting)
                } else {
                    Button("Next") { withAnimation(pagingAnimation) { model.advance() } }
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
