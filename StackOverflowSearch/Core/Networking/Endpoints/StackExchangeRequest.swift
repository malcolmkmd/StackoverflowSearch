//
//  StackExchangeRequest.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

enum StackExchangeRequest {
    static func commonQueryItems() -> [URLQueryItem] {
        [
            URLQueryItem(name: "pagesize", value: "20"),
            URLQueryItem(name: "site", value: "stackoverflow"),
            URLQueryItem(name: "filter", value: "withbody"),
        ]
    }
    
    static func sortedListItems(page: Int, sort: String, order: String) -> [URLQueryItem] {
        [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "order", value: order),
            URLQueryItem(name: "sort", value: sort),
        ]
    }
}
