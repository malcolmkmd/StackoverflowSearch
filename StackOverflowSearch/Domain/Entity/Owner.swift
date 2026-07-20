//
//  Owner.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import Foundation

struct Owner: Sendable, Hashable, Identifiable {
    var id: Int
    let displayName: String
    let reputation: Int
    let avatarURL: URL?
    let profileLink: URL?
}
