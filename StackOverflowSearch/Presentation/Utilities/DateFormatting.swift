//
//  DateFormatting.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//
import Foundation

enum DateFormatting {
    static func askedListString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d ''yy"
        return formatter.string(from: date)
    }
}
