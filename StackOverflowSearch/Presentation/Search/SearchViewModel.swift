//
//  SearchViewModel.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//
import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    
    var query = ""
    var path: [AppRoute] = []
    
    init() {}
    
    func goToQuestion() {
        path.append(.question)
    }
    
    func onSubmit() {
        
    }
}
