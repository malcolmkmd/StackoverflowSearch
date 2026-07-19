//
//  Question.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//
import Foundation

struct Question: Sendable, Hashable, Identifiable {
    let id: Int64
    let title: String
    let bodyHTML: String
    let tags: [String]
    let isAnswered: Bool
    let viewCount: Int
    let answerCount: Int
    let score: Int
    let askedAt: Date
    let activeAt: Date
    let acceptedAnswerID: Int?
    let link: URL?
    let owner: Owner?
}

extension Question {
    static func mock() -> Question {
        let id = Int64.random(in: 0...10)
        return Question(id: id, title: "question \(id)", bodyHTML: "sxs", tags: [], isAnswered: true, viewCount: 120, answerCount: 21, score: 2, askedAt: Date(), activeAt: Date(), acceptedAnswerID: 21, link: nil, owner: nil)
    }
}
