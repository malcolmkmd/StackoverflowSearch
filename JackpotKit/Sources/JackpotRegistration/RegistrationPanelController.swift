import UIKit
import SwiftUI

/// Drop-in replacement for the legacy registration popup.
///
/// Hosting in a view controller — rather than handing a bare `UIView` to the existing popup
/// container — is what makes safe areas, keyboard avoidance and environment propagation work.
/// `panelView` is there for containers that still expect a `UIView`.
///
/// ```swift
/// let controller = RegistrationPanelController(
///     dependencies: .mock(localizer: legacyLocalizer),
///     onClose: { popupContainer.dismiss() },
///     onLogin: { popupContainer.dismiss(); presentLogin() }
/// ) { result in
///     // route to OTP / login / home
/// }
/// addChild(controller)
/// popupContainer.show(controller.view)
/// controller.didMove(toParent: self)
/// ```
public final class RegistrationPanelController: UIHostingController<RegistrationView> {

    public init(dependencies: RegistrationDependencies,
                onClose: @escaping () -> Void,
                onLogin: @escaping () -> Void,
                onComplete: @escaping (RegistrationResult) -> Void) {
        super.init(rootView: RegistrationView(dependencies: dependencies,
                                              onClose: onClose,
                                              onLogin: onLogin,
                                              onComplete: onComplete))
        view.backgroundColor = .clear
        if #available(iOS 16.0, *) { sizingOptions = [.intrinsicContentSize] }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(dependencies:onClose:onLogin:onComplete:)") }

    /// For legacy containers that take a `UIView`. The controller must still be added as a
    /// child of whatever presents it.
    public var panelView: UIView { view }
}
