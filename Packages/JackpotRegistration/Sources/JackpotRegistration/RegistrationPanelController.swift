import UIKit
import SwiftUI

/// Drop-in replacement for the legacy registration popup.
///
/// The old flow was a nib-backed `UIView` shown over dimmed content. This hosts the SwiftUI
/// feature in a view controller so safe areas, keyboard avoidance and environment propagation
/// work, and exposes `panelView` for containers that expect a `UIView`.
///
/// App-side usage (the entirety of the final PR's wiring):
///
/// ```swift
/// let controller = RegistrationPanelController(dependencies: .mock(localizer: legacyLocalizer)) { result in
///     // route to OTP / login / home
/// }
/// addChild(controller)
/// popupContainer.show(controller.view)
/// controller.didMove(toParent: self)
/// ```
public final class RegistrationPanelController: UIHostingController<RegistrationView> {

    public init(dependencies: RegistrationDependencies, onComplete: @escaping (RegistrationResult) -> Void) {
        super.init(rootView: RegistrationView(dependencies: dependencies, onComplete: onComplete))
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) { sizingOptions = [.intrinsicContentSize] }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(dependencies:onComplete:)") }

    /// For legacy containers that take a `UIView`. The controller must still be added as a
    /// child of whatever presents it.
    public var panelView: UIView { view }
}
