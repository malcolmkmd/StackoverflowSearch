//
//  Page.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

struct Page<Item: Sendable>: Sendable {
    let items: [Item]
    let hasMore: Bool
}
