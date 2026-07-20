//
//  OwnerMapper.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

import Foundation

enum OwnerMapper {
    static func map(_ dto: OwnerDTO) -> Owner {
        Owner(
            id: dto.userID ?? 0,
            displayName: (dto.displayName ?? "Anonymous"),
            reputation: dto.reputation ?? 0,
            avatarURL: dto.profileImage.flatMap(URL.init(string:)),
            profileLink: dto.link.flatMap(URL.init(string:))
        )
    }
}

