//
//  QuestionDetailViewModel.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import Foundation
import Observation

@MainActor
@Observable
final class QuestionDetailViewModel {

    let question: Question

    private let questionRepository: any QuestionRepository

    init(question: Question, questionRepository: any QuestionRepository) {
        self.question = question
        self.questionRepository = questionRepository
    }

}
