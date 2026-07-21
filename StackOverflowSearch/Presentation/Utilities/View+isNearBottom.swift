//
//  View+isNearBottom.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

extension View {
    func isNearBottom(triggerDistance: CGFloat = 300, perform action: @escaping () -> Void) -> some View {
        onScrollGeometryChange(for: Bool.self) { geometry in
            guard geometry.contentSize.height > 0 else { return false }
            let maxOffset = geometry.contentSize.height - geometry.containerSize.height
            return geometry.contentOffset.y >= maxOffset - triggerDistance
        } action: { _, isNearBottom in
            guard isNearBottom else { return }
            action()
        }
    }
}
