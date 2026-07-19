//
//  QuestionDetailView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI

struct QuestionDetailView: View {
    
    let question: Question
    
    init(question: Question) {
        self.question = question
    }
    
    var body: some View {
        Text(question.title)
            .navigationTitle("More Info")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    QuestionDetailView(question: Question.mock())
}
