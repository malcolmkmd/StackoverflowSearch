//
//  SearchRequest.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

struct SearchRequest: APIEndpoint {
    var path: String { "search/advanced" }
    let query: String
    let page: Int
    
    var queryItems: [URLQueryItem] {
        StackExchangeRequest.sortedListItems(page: page, sort: "activity", order: "desc")
        + [URLQueryItem(name: "title", value: query)]
    }
}
