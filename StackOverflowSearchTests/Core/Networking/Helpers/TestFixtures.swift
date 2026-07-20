//
//  TestFixtures.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

enum TestFixtures {
    static let questionListJSON = """
    {
      "items": [
        {
          "tags": ["ios", "swift"],
          "owner": {
            "reputation": 100,
            "user_id": 1,
            "display_name": "Alice",
            "profile_image": "https://example.com/a.png",
            "link": "https://stackoverflow.com/users/1"
          },
          "is_answered": true,
          "view_count": 10,
          "accepted_answer_id": 99,
          "answer_count": 2,
          "score": 5,
          "last_activity_date": 1700000000,
          "creation_date": 1600000000,
          "question_id": 42,
          "link": "https://stackoverflow.com/questions/42",
          "title": "Hello &#39;world&#39;",
          "body": "<p>Body</p>"
        }
      ],
      "has_more": true
    }
    """.data(using: .utf8)!

    static let answerListJSON = """
    {
      "items": [
        {
          "owner": {
            "reputation": 50,
            "display_name": "Bob",
            "profile_image": "https://example.com/b.png",
            "link": "https://stackoverflow.com/users/2"
          },
          "is_accepted": true,
          "score": 9,
          "last_activity_date": 1600000200,
          "creation_date": 1600000100,
          "answer_id": 99,
          "question_id": 42,
          "body": "<p>Answer body</p>"
        }
      ],
      "has_more": false
    }
    """.data(using: .utf8)!
}
