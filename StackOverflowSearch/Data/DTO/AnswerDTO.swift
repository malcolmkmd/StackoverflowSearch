//
//  AnswerDTO.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

struct AnswerDTO: Decodable, Sendable {
    let answerID: Int
    let questionID: Int
    let body: String?
    let isAccepted: Bool?
    let score: Int?
    let creationDate: TimeInterval?
    let lastActivityDate: TimeInterval?
    let owner: OwnerDTO?

    enum CodingKeys: String, CodingKey {
        case answerID = "answer_id"
        case questionID = "question_id"
        case body
        case isAccepted = "is_accepted"
        case score
        case creationDate = "creation_date"
        case lastActivityDate = "last_activity_date"
        case owner
    }
}

struct AnswerListResponseDTO: Decodable, Sendable {
    let items: [AnswerDTO]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
    }
}
