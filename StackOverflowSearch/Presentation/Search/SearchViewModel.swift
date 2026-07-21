//
//  SearchViewModel.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//
import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    typealias ViewState = PaginatedList<Question>.ViewState
    
    var viewState: ViewState { list.viewState }
    var questions: [Question] { list.items }
    var hasMorePages: Bool { list.hasMorePages }
    var isPrefetching: Bool { list.isPrefetching }

    var query = ""
    var path: [AppRoute] = []

    private let list = PaginatedList<Question>()
    private let questionRepository: any QuestionRepository
    private static let debounceNanoseconds: UInt64 = 400_000_000

    init(questionRepository: any QuestionRepository) {
        self.questionRepository = questionRepository
    }
    
    func loadInitial() {
        queryDidChange(instant: true)
    }

    func queryDidChange(instant: Bool = false) {
        let requestedQuery = query
        list.load(delayNanoseconds: instant ? 0 : Self.debounceNanoseconds) { [questionRepository] page in
            try await questionRepository.fetchQuestions(query: requestedQuery, page: page)
        }
    }

    func retry() {
        queryDidChange(instant: true)
    }

    func didSelectQuestion(_ question: Question) {
        path.append(.questionDetail(question))
    }

    func prefetchNextPageIfNeeded() {
        list.prefetchNextPage()
    }
}
