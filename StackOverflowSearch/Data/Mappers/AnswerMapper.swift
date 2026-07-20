//
//  AnswerMapper.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

enum AnswerMapper {
    static func map(_ dto: AnswerDTO) -> Answer {
        Answer(
            id: dto.answerID,
            questionID: dto.questionID,
            bodyHTML: dto.body ?? "",
            isAccepted: dto.isAccepted ?? false,
            score: dto.score ?? 0,
            createdAt: Date(timeIntervalSince1970: dto.creationDate ?? 0),
            lastActivityAt: Date(timeIntervalSince1970: dto.lastActivityDate ?? dto.creationDate ?? 0),
            owner: dto.owner.map(OwnerMapper.map)
        )
    }

    static func mapPage(_ dto: AnswerListResponseDTO) -> Page<Answer> {
        Page(items: dto.items.map(map), hasMore: dto.hasMore)
    }
}
