//
//  Skeletons.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

struct SearchRowSkeleton: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SkeletonBar(width: 24, height: 24, cornerRadius: 3)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(width: 220, height: 14)
                SkeletonBar(height: 10)
                SkeletonBar(width: 180, height: 10)
                SkeletonBar(width: 140, height: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 8) {
                SkeletonBar(width: 56, height: 16)
                SkeletonBar(width: 48, height: 16)
                SkeletonBar(width: 44, height: 16)
            }
        }
        .padding(.vertical, 8)
        .shimmer()
    }
}

struct BodySkeleton: View {
    let lineWidths: [CGFloat?] = [nil, nil, 260, 180, 200]
    let minHeight: CGFloat = 140

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lineWidths.enumerated()), id: \.offset) { _, width in
                SkeletonBar(width: width, height: 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .shimmer()
    }
}

struct AnswerRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                SkeletonBar(width: 40, height: 12)
                SkeletonBar(width: 22, height: 22, cornerRadius: 3)
            }
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar(height: 12)
                SkeletonBar(height: 12)
                SkeletonBar(width: 160, height: 12)
                HStack {
                    SkeletonBar(width: 100, height: 36)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 10)
        .shimmer()
    }
}

private struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.25))
            .frame(maxWidth: width == nil ? .infinity : width)
            .frame(height: height)
    }
}

private extension View {
    @ViewBuilder
    func shimmer() -> some View {
        modifier(ShimmerModifier())
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
