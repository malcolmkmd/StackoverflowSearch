//
//  Answer.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

struct Answer: Sendable, Equatable, Hashable, Identifiable {
    let id: Int
    let questionID: Int
    let bodyHTML: String
    let isAccepted: Bool
    let score: Int
    let createdAt: Date
    let lastActivityAt: Date
    let owner: Owner?
}
