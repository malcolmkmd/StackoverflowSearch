//
//  String+HTMLStripping.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import Foundation

extension String {
    func strippingHTMLTags() -> String {
        self
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
