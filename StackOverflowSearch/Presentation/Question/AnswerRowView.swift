//
//  AnswerRowView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

struct AnswerRowView: View {
    let answer: Answer
    @State private var bodyHeight: CGFloat = 80
    @State private var isBodyReady = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 8) {
                Text("\(answer.score) Votes")
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                    .padding(.top, 20)

                if answer.isAccepted {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.orange)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .top) {
                    HTMLWebView(
                        html: answer.bodyHTML,
                        height: $bodyHeight,
                        onContentReady: { isBodyReady = true }
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: bodyHeight)
                    .opacity(isBodyReady ? 1 : 0)

                    if !isBodyReady {
                        BodySkeleton()
                    }
                }
                .frame(height: isBodyReady ? bodyHeight : 72, alignment: .top)
                .clipped()

                if isBodyReady {
                    ownerBlock
                }
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var ownerBlock: some View {
        if let owner = answer.owner {
            UserView(
                owner: owner,
                captionLabel: "answered",
                captionValue: DateFormatting.askedDetailString(from: answer.createdAt),
                avatarSize: 32
            )
        }
    }
}
