//
//  QuestionRepository.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

protocol QuestionRepository: Sendable {
    func fetchQuestions(query: String, page: Int) async throws -> Page<Question>
    func fetchAnswers(questionID: Int, sort: AnswerSortOrder, page: Int) async throws -> Page<Answer>
}
