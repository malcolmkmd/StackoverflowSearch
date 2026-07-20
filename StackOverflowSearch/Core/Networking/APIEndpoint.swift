//
//  APIEndpoint.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

protocol APIEndpoint: Sendable {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    func asURLRequest() -> URLRequest
}

extension APIEndpoint {
    var baseURL: URL { URL(string: "https://api.stackexchange.com/2.2")! }
    var method: HTTPMethod { .GET }
    var headers: [String: String] { ["Accept": "application/json"] }
    var queryItems: [URLQueryItem] { [] }
    
    func asURLRequest() -> URLRequest {
        var url = baseURL.appending(path: path, directoryHint: .notDirectory)
        let queryItems = StackExchangeRequest.commonQueryItems() + queryItems
        if !queryItems.isEmpty {
            url.append(queryItems: queryItems)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        return request
    }
}
