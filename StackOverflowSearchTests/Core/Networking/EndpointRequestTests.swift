//
//  EndpointRequestTests.swift
//  StackOverflowSearchTests
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation
import Testing
@testable import StackOverflowSearch

struct EndpointRequestTests {
    @Test("Search request URL")
    func searchRequestURL() throws {
        let request = SearchRequest(query: "swiftui", page: 1).asURLRequest()
        let url = try #require(request.url)
        #expect(
            url.absoluteString
                == "https://api.stackexchange.com/2.2/search/advanced?pagesize=20&site=stackoverflow&filter=withbody&page=1&order=desc&sort=activity&title=swiftui"
        )
    }

    @Test("Answers request URL")
    func answersRequestURL() throws {
        let request = AnswersRequest(questionID: 42, sort: "votes", order: "desc", page: 3).asURLRequest()
        let url = try #require(request.url)
        #expect(
            url.absoluteString
                == "https://api.stackexchange.com/2.2/questions/42/answers?pagesize=20&site=stackoverflow&filter=withbody&page=3&order=desc&sort=votes"
        )
    }
}
