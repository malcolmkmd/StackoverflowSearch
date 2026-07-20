//
//  AnswerSortOrder.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

enum AnswerSortOrder: String, CaseIterable, Sendable, Identifiable {
    case active
    case oldest
    case votes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: "Active"
        case .oldest: "Oldest"
        case .votes: "Votes"
        }
    }

    var apiSort: String {
        switch self {
        case .active: "activity"
        case .oldest: "creation"
        case .votes: "votes"
        }
    }

    var apiOrder: String {
        switch self {
        case .active, .votes: "desc"
        case .oldest: "asc"
        }
    }
}
