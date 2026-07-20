//
//  HTTPClient.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

protocol HTTPClient: Sendable {
    func request(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPClient {
    func request(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}
