//
//  MockHTTPClient.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation
@testable import StackOverflowSearch

actor MockHTTPClient: HTTPClient {

    enum Invocation: Equatable, Sendable {
        case request(url: URL?, httpMethod: String?)
    }

    private(set) var recordedInvocations: [Invocation] = []
    private var stubbedData: Data = Data()
    private var stubbedStatusCode: Int = 500
    private var stubbedURL: URL = URL(string: "https://api.stackexchange.com/2.2/questions")!
    private var stubbedError: (any Error)?

    func request(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recordedInvocations.append(
            .request(url: urlRequest.url, httpMethod: urlRequest.httpMethod)
        )

        if let stubbedError {
            throw stubbedError
        }

        let response = HTTPURLResponse(
            url: stubbedURL,
            statusCode: stubbedStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stubbedData, response)
    }

    func stubSuccess(
        data: Data,
        statusCode: Int = 200,
        url: URL = URL(string: "https://api.stackexchange.com/2.2/questions")!
    ) {
        stubbedData = data
        stubbedStatusCode = statusCode
        stubbedURL = url
        stubbedError = nil
    }

    func stubFailure(_ error: any Error) {
        stubbedError = error
    }

}
