//
//  AnswersRequest.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

struct AnswersRequest: APIEndpoint {
    var path: String { "questions/\(questionID)/answers" }
    
    let questionID: Int
    let sort: String
    let order: String
    let page: Int
    
    var queryItems: [URLQueryItem] {
        StackExchangeRequest.sortedListItems(page: page, sort: sort, order: order)
    }
    
}
