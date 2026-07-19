//
//  SearchRowView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI

struct SearchRowView: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(question.isAnswered ? Theme.orange : Color.clear)
                    .frame(width: 24, alignment: .center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Q: \(question.title)")
                        .font(.system(size: 14).weight(.medium))
                        .foregroundStyle(Theme.linkBlue)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(question.bodyHTML)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)

                    askedLine
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(question.answerCount) answers")
                    Text("\(question.score) votes")
                    Text("\(question.viewCount) views")
                }
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .fixedSize()

                Image(systemName: "chevron.right")
                    .font(.title)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Rectangle()
                .fill(.primary)
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
        }
    }

    private var askedLine: some View {
        let date = DateFormatting.askedListString(from: question.askedAt)
        let name = question.owner?.displayName ?? "unknown"
        let askedText = Text("asked \(date) by ").foregroundStyle(.primary)
        let nameText = Text(name).foregroundStyle(Theme.linkBlue)
        return Text("\(askedText)\(nameText)")
        .font(.caption)
        .lineLimit(1)
        .multilineTextAlignment(.leading)
    }

}

#Preview {
    SearchRowView(question: Question.mock)
}
