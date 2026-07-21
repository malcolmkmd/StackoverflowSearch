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
    @ObservationIgnored private var lastQuery: String?
    var path: [AppRoute] = []

    private let list = PaginatedList<Question>()
    private let questionRepository: any QuestionRepository
    private static let debounceNanoseconds: UInt64 = 400_000_000

    init(questionRepository: any QuestionRepository) {
        self.questionRepository = questionRepository
    }
    
    func loadInitial() {
        loadCurrentQuery(instant: true, force: true)
    }

    func queryDidChange(instant: Bool = false) {
        loadCurrentQuery(instant: instant)
    }

    func retry() {
        loadCurrentQuery(instant: true, force: true)
    }
    
    private func loadCurrentQuery(instant: Bool = false, force: Bool = false) {
        let requestedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard force || lastQuery != requestedQuery else { return }
        lastQuery = requestedQuery
        
        list.load(delayNanoseconds: instant ? 0 : Self.debounceNanoseconds) { [questionRepository] page in
            try await questionRepository.fetchQuestions(query: requestedQuery, page: page)
        }
    }

    func didSelectQuestion(_ question: Question) {
        path.append(.questionDetail(question))
    }

    func prefetchNextPageIfNeeded() {
        list.prefetchNextPage()
    }
}
