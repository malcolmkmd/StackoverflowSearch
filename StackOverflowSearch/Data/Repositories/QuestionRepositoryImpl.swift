//
//  QuestionRepositoryImpl.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

struct QuestionRepositoryImpl: QuestionRepository {
    
    private let apiClient: any ApiClient
    
    init(apiClient: any ApiClient) {
        self.apiClient = apiClient
    }
    
    func fetchQuestions(query: String, page: Int) async throws -> Page<Question> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchQuery = trimmed.isEmpty ? "swift" : trimmed
        let endpoint: any APIEndpoint = SearchRequest(query: searchQuery, page: page)
        return try await perform(endpoint, mapping: QuestionMapper.mapPage)
    }
    
    func fetchAnswers(questionID: Int, sort: AnswerSortOrder, page: Int) async throws -> Page<Answer> {
        let endpoint = AnswersRequest(
            questionID: questionID,
            sort: sort.apiSort,
            order: sort.apiOrder,
            page: page
        )
        return try await perform(endpoint, mapping: AnswerMapper.mapPage)
    }
    
    private func perform<DTO: Decodable & Sendable, Model>(_ endPoint: some APIEndpoint, mapping: (DTO) -> Model) async throws -> Model {
        do {
            let dto: DTO = try await apiClient.request(endPoint)
            return mapping(dto)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }
    }
    
}
