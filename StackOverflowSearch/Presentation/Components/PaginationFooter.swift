//
//  PaginationFooter.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//
import SwiftUI

struct PaginationFooter: View {
    let isPrefetching: Bool
    let hasMorePages: Bool

    var body: some View {
        Group {
            if isPrefetching && hasMorePages {
                Text("More results loading…")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
    }
}
