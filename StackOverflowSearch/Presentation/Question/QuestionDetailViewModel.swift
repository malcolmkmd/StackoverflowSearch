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
    
    typealias ViewState = PaginatedList<Answer>.ViewState
    private let list = PaginatedList<Answer>()
    var viewState: ViewState { list.viewState }
    var answers: [Answer] { list.items }
    var hasMorePages: Bool { list.hasMorePages }
    var isPrefetching: Bool { list.isPrefetching }
    
    private(set) var sortOrder: AnswerSortOrder = .votes
    private let questionRepository: any QuestionRepository

    init(question: Question, questionRepository: any QuestionRepository) {
        self.question = question
        self.questionRepository = questionRepository
    }
    
    func loadAnswers() {
        let questionID = question.id
        let sort = sortOrder
        list.load { [questionRepository] page in
            try await questionRepository.fetchAnswers(
                questionID: questionID,
                sort: sort,
                page: page
            )
        }
    }
    
    func selectSort(_ sort: AnswerSortOrder) {
        guard sort != sortOrder else { return }
        sortOrder = sort
        loadAnswers()
    }
    
    func retry() {
        loadAnswers()
    }

    func cancelWork() {
        list.cancel()
    }

    func prefetchNextPageIfNeeded() {
        list.prefetchNextPage()
    }

}
