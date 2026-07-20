//
//  QuestionsRequest.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

struct QuestionsRequest: APIEndpoint {
    let page: Int
    
    var path: String { "questions" }
    
    var queryItems: [URLQueryItem] {
        StackExchangeRequest.sortedListItems(page: page, sort: "activity", order: "desc")
    }
}
