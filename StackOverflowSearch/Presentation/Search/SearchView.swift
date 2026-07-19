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
                content
            }.navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .questionDetail(let question):
                    QuestionDetailView(question: question)
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
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.viewState {
        case .loading:
            List {
                ForEach(0..<8, id: \.self) { _ in
                    Text("Loading")
                        .listRowSeparator(.visible)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
        case .loaded(let questions) where questions.isEmpty:
            Text("Nothing to see here")
        case .loaded(let questions):
            List {
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    Button {
                        viewModel.didSelect(question)
                    } label: {
                        SearchRowView(question: question)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
        case .failed(let message):
            Text("something went wrong: \(message)")
        }
    }
}

#Preview {
    SearchView()
}

