//
//  Text+LabelCaption.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

extension Text {
    static func labeledCaption(_ label: String, value: String) -> Text {
        let label = Text(label).foregroundStyle(.secondary)
        let value = Text(value).foregroundStyle(.primary)
        return Text("\(label) \(value)").font(.caption)
    }
}
