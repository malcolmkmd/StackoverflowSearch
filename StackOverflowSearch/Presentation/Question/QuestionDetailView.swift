//
//  QuestionDetailView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI

struct QuestionDetailView: View {
    @State private var viewModel: QuestionDetailViewModel
    @State private var questionBodyHeight: CGFloat = 140
    @State private var isQuestionHTMLReady = false

    init(question: Question, questionRepository: any QuestionRepository) {
        _viewModel = State(
            initialValue: QuestionDetailViewModel(question: question, questionRepository: questionRepository)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                questionHeader
                Divider()
                questionBody
                tags
                askerBlock
                Divider()
                AnswerList(viewModel: viewModel)
            }
            .padding()
        }
        .navigationTitle("More Info")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.loadAnswers()
        }
        .onDisappear {
            viewModel.cancelWork()
        }
    }

    private var questionBody: some View {
        ZStack(alignment: .top) {
            HTMLWebView(
                html: viewModel.question.bodyHTML,
                height: $questionBodyHeight,
                onContentReady: { isQuestionHTMLReady = true }
            )
            .frame(maxWidth: .infinity)
            .frame(height: questionBodyHeight)
            .opacity(isQuestionHTMLReady ? 1 : 0)
            
            if !isQuestionHTMLReady {
                BodySkeleton()
            }
        }
        .frame(height: isQuestionHTMLReady ? questionBodyHeight : 140, alignment: .top)
        .clipped()
    }

    private var questionHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.question.title)
                .font(.title3.weight(.bold))

            HStack(spacing: 16) {
                Text.labeledCaption(
                    "Asked",
                    value: DateFormatting.relativeString(from: viewModel.question.askedAt)
                )
                Text.labeledCaption(
                    "Active",
                    value: DateFormatting.relativeString(from: viewModel.question.activeAt)
                )
                Text.labeledCaption(
                    "Viewed",
                    value: "\(viewModel.question.viewCount) times"
                )
            }
        }
    }

    private var tags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.question.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.tagBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    @ViewBuilder
    private var askerBlock: some View {
        if let owner = viewModel.question.owner {
            UserView(
                owner: owner,
                captionLabel: "Asked",
                captionValue: DateFormatting.askedDetailString(from: viewModel.question.askedAt),
                avatarSize: 36
            )
        }
    }

}

#Preview {
    QuestionDetailView(question: Question.mock(), questionRepository: QuestionRepositoryImpl(apiClient: RemoteApiClient()))
}
