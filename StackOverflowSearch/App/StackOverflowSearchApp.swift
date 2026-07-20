//
//  StackOverflowSearchApp.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI

@main
struct StackOverflowSearchApp: App {
    
    private let dependencies = AppDependencies.live()
    
    var body: some Scene {
        WindowGroup {
            SearchView(questionRepository: dependencies.questionRepository)
        }
    }
}
