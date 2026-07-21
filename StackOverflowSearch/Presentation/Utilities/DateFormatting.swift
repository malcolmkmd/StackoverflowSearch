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
    
    static func askedDetailString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy 'at' HH:mm"
        return formatter.string(from: date)
    }
    
    static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
