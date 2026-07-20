//
//  QuestionMapper.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

enum QuestionMapper {
    static func map(_ dto: QuestionDTO) -> Question {
        Question(
            id: dto.questionID,
            title: dto.title,
            bodyHTML: dto.body ?? "",
            tags: dto.tags ?? [],
            isAnswered: dto.isAnswered ?? false,
            viewCount: dto.viewCount ?? 0,
            answerCount: dto.answerCount ?? 0,
            score: dto.score ?? 0,
            askedAt: Date(timeIntervalSince1970: dto.creationDate ?? 0),
            activeAt: Date(timeIntervalSince1970: dto.lastActivityDate ?? dto.creationDate ?? 0),
            acceptedAnswerID: dto.acceptedAnswerID,
            link: dto.link.flatMap(URL.init(string:)),
            owner: dto.owner.map(OwnerMapper.map)
        )
    }

    static func mapPage(_ dto: QuestionListResponseDTO) -> Page<Question> {
        Page(items: dto.items.map(map), hasMore: dto.hasMore)
    }
}
