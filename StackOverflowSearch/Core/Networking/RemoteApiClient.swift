//
//  RemoteApiClient.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

protocol ApiClient: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: some APIEndpoint) async throws -> Response
}

struct RemoteApiClient: ApiClient {
    
    private let httpClient: any HTTPClient
    private let decoder: JSONDecoder
    
    init(
        httpClient: any HTTPClient = URLSession.shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.httpClient = httpClient
        self.decoder = decoder
    }
    
    func request<Response>(_ endpoint: some APIEndpoint) async throws -> Response where Response : Decodable, Response : Sendable {
        let urlRequest = endpoint.asURLRequest()
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await httpClient.request(urlRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost || urlError.code == .dataNotAllowed {
            throw APIError.transport("no connection")
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.httpStatus(response.statusCode, data)
        }
        
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
    
}
