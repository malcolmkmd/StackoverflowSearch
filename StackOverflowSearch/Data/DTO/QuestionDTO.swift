//
//  QuestionDTO.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

struct QuestionDTO: Decodable, Sendable {
    let questionID: Int
    let title: String
    let body: String?
    let tags: [String]?
    let isAnswered: Bool?
    let viewCount: Int?
    let answerCount: Int?
    let score: Int?
    let creationDate: TimeInterval?
    let lastActivityDate: TimeInterval?
    let acceptedAnswerID: Int?
    let link: String?
    let owner: OwnerDTO?

    enum CodingKeys: String, CodingKey {
        case questionID = "question_id"
        case title
        case body
        case tags
        case isAnswered = "is_answered"
        case viewCount = "view_count"
        case answerCount = "answer_count"
        case score
        case creationDate = "creation_date"
        case lastActivityDate = "last_activity_date"
        case acceptedAnswerID = "accepted_answer_id"
        case link
        case owner
    }
}

struct QuestionListResponseDTO: Decodable, Sendable {
    let items: [QuestionDTO]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
    }
}
