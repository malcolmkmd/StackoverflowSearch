//
//  UserView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import SwiftUI

struct UserView: View {
    let owner: Owner
    let captionLabel: String
    let captionValue: String
    var avatarSize: CGFloat = 36

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text.labeledCaption(captionLabel, value: captionValue)
                HStack(spacing: 8) {
                    AsyncImage(url: owner.avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.gray.opacity(0.3)
                        }
                    }
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(owner.displayName)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        Text("\(owner.reputation)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}
