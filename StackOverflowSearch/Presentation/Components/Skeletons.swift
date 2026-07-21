//
//  Skeletons.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

struct QuestionBodySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bar(height: 12)
            bar(height: 12)
            bar(width: 260, height: 12)
            bar(height: 12)
            bar(width: 200, height: 12)
            bar(width: 180, height: 12)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(.vertical, 4)
        .redacted(reason: .placeholder)
        .modifier(ShimmerModifier())
    }

    private func bar(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.25))
            .frame(maxWidth: width == nil ? .infinity : width)
            .frame(height: height)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .opacity(0.55 + 0.35 * abs(sin(phase)))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    phase = .pi
                }
            }
    }
}
