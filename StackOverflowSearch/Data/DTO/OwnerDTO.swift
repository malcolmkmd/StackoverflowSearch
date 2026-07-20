//
//  OwnerDTO.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//
import Foundation

struct OwnerDTO: Decodable, Sendable {
    let reputation: Int?
    let userID: Int?
    let displayName: String?
    let profileImage: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case reputation
        case userID = "user_id"
        case displayName = "display_name"
        case profileImage = "profile_image"
        case link
    }
}
