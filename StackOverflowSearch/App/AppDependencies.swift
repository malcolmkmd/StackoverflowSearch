//
//  AppDependencies.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/20.
//

@MainActor
struct AppDependencies {
    let questionRepository: any QuestionRepository
    
    static func live() -> AppDependencies {
        AppDependencies(questionRepository: QuestionRepositoryImpl(apiClient: RemoteApiClient()))
    }
}
