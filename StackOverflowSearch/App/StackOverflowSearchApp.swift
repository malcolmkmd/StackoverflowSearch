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
    
    @State private var hasEntered = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasEntered {
                    SearchView(questionRepository: dependencies.questionRepository)
                        .noNetworkOverlay(monitor: dependencies.networkMonitor)
                        .transition(.opacity)
                } else {
                    LaunchView(onLogin: { hasEntered = true })
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.35), value: hasEntered)
        }
    }
}
