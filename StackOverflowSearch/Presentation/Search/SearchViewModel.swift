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
    enum ViewState {
        case loading
        case loaded([Question])
        case failed(String)
    }
    
    var viewState: ViewState = .loaded([Question.mock(), Question.mock()])
    var query = ""
    var path: [AppRoute] = []
    private let questionRepository: any QuestionRepository
    
    init(questionRepository: any QuestionRepository) {
        self.questionRepository = questionRepository
    }
    
    func loadInitial() async {
        do {
            let page = try await questionRepository.fetchQuestions(query: query, page: 1)
            viewState = .loaded(page.items)
        } catch {
            viewState = .failed(error.localizedDescription)
        }
    }
    
    func didSelect(_ question: Question) {
        path.append(.questionDetail(question))
    }
    
    func onSubmit() {
        
    }
}
