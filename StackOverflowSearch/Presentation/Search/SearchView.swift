//
//  SearchView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI

struct SearchView: View {
    
    @State private var viewModel: SearchViewModel
    
    init() {
        _viewModel = State(initialValue: SearchViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.path) {
            VStack {
                header
                searchField
                Spacer()
            }.navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .question:
                    QuestionDetailView()
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 4) {
                Image("logo")
                    .resizable()
                    .frame(width: 200, height: 40)
                    .foregroundStyle(Theme.orange)
            }
            Spacer()
            Color.clear.frame(width: 22, height: 22)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search...", text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { viewModel.onSubmit() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.secondaryText, lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
        )
        .padding([.horizontal, .vertical], 8)
        .background(Theme.orange)
    }
}

#Preview {
    SearchView()
}
