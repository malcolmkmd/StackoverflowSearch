//
//  APIError.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

enum APIError: Error, Sendable, Equatable {
    case decoding(String)
    case transport(String)
    case httpStatus(Int, Data)
}
