//
//  RemoteApiClientTests.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation
import Testing
@testable import StackOverflowSearch

struct RemoteApiClientTests {
    @Test("Builds request with correct properties")
    func buildsRequest() async throws {
        let mockHTTPClient = MockHTTPClient()
        await mockHTTPClient.stubSuccess(data: TestFixtures.questionListJSON)
        
        let client = RemoteApiClient(httpClient: mockHTTPClient)
        let dto: QuestionListResponseDTO = try await client.request(QuestionsRequest(page: 1))
        
        #expect(dto.items.count == 1)
        #expect(dto.hasMore == true)
        
        let invocations = await mockHTTPClient.recordedInvocations
        let invocation = try #require(invocations.first)
        guard case .request(let url, let httpMethod) = invocation else {
            Issue.record("Expected request invocation")
            return
        }
        #expect(httpMethod == "GET")
        #expect(url?.absoluteString == "https://api.stackexchange.com/2.2/questions?pagesize=20&site=stackoverflow&filter=withbody&page=1&order=desc&sort=activity")
    }
    
    enum RequestErrorCase: String, CaseIterable, Sendable {
        case noConnection
        case networkConnectionLost
        case dataNotAllowed
        case transport
        case httpStatus
        case decoding
        case cancellation
    }
    
    @Test("RemoteApiClient request error handling", arguments: RequestErrorCase.allCases)
    func requestErrorHandling(failure: RequestErrorCase) async {
        let mockHTTPClient = MockHTTPClient()
        let client = RemoteApiClient(httpClient: mockHTTPClient)
        
        switch failure {
        case .noConnection:
            await mockHTTPClient.stubFailure(URLError(.notConnectedToInternet))
            await #expect(throws: APIError.transport("no connection")) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
        case .networkConnectionLost:
            await mockHTTPClient.stubFailure(URLError(.networkConnectionLost))
            await #expect(throws: APIError.transport("no connection")) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
        case .dataNotAllowed:
            await mockHTTPClient.stubFailure(URLError(.dataNotAllowed))
            await #expect(throws: APIError.transport("no connection")) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
        case .transport:
            let urlError = URLError(.timedOut)
            await mockHTTPClient.stubFailure(urlError)
            await #expect(throws: APIError.transport(urlError.localizedDescription)) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
        case .httpStatus:
            let body = Data("not found".utf8)
            await mockHTTPClient.stubSuccess(data: body, statusCode: 404)
            await #expect(throws: APIError.httpStatus(404, body)) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
        case .decoding:
            await mockHTTPClient.stubSuccess(data: Data("not-json".utf8))
            let error = await #expect(throws: APIError.self) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
            guard case .decoding = error else {
                Issue.record("Expected decoding error, got \(String(describing: error))")
                return
            }
        case .cancellation:
            await mockHTTPClient.stubFailure(CancellationError())
            await #expect(throws: CancellationError.self) {
                try await client.request(QuestionsRequest(page: 1)) as QuestionListResponseDTO
            }
        }
    }
}
