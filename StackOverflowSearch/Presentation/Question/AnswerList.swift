//
//  AnswerList.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

struct AnswerList: View {
    
    @State private var viewModel: QuestionDetailViewModel
    
    init(viewModel: QuestionDetailViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(viewModel.question.answerCount) Answers")
                    .font(.title3.weight(.bold))
                Spacer()
                Picker("Sort", selection: Binding(
                    get: { viewModel.sortOrder },
                    set: { viewModel.selectSort($0) }
                )) {
                    ForEach(AnswerSortOrder.allCases) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            switch viewModel.viewState {
            case .loading:
                ForEach(0..<3, id: \.self) { _ in
                    AnswerRowSkeleton()
                }
            case .loaded(let answers) where answers.isEmpty:
                ContentUnavailableView {
                    Label("No answers here", systemImage: "magnifyingglass")
                } description: {
                    Text("Try again..")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let answers):
                ForEach(Array(answers.enumerated()), id: \.element.id) { index, answer in
                    VStack(spacing: 4) {
                        AnswerRowView(answer: answer)
                        if index < answers.count - 1 {
                            Rectangle()
                                .fill(.primary)
                                .frame(height: 0.5)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                PaginationFooter(
                    isPrefetching: viewModel.isPrefetching,
                    hasMorePages: viewModel.hasMorePages
                )
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load answers", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { viewModel.retry() }
                }
                .frame(minHeight: 180)
            }
        }
    }
    
}
