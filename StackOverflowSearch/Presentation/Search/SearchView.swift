//
//  SearchView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI

struct SearchView: View {
    
    @State private var viewModel: SearchViewModel
    
    init(questionRepository: any QuestionRepository) {
        _viewModel = State(initialValue: SearchViewModel(questionRepository: questionRepository))
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.path) {
            VStack {
                header
                searchField
                content
            }
            .background(Color(.systemBackground))
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .questionDetail(let question):
                    QuestionDetailView(question: question)
                }
            }
        }.task {
            viewModel.loadInitial()
        }.onChange(of: viewModel.query) {
            viewModel.queryDidChange()
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
                .onSubmit { viewModel.queryDidChange(instant: true, ) }
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
        List {
            ForEach(viewModel.questions) { question in
                Button {
                    viewModel.didSelectQuestion(question)
                } label: {
                    SearchRowView(question: question)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            PaginationFooter(
                isPrefetching: viewModel.isPrefetching,
                hasMorePages: viewModel.hasMorePages
            )
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .isNearBottom {
            viewModel.prefetchNextPageIfNeeded()
        }
        .overlay(alignment: .center) {
            switch viewModel.viewState {
            case .loading:
                ProgressView()
                    .controlSize(.extraLarge)
                    .frame(maxWidth: .infinity)
            case .loaded(let questions) where questions.isEmpty:
                ContentUnavailableView {
                    Label("No questions", systemImage: "magnifyingglass")
                } description: {
                    Text("Try again..")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded: EmptyView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("Something went wrong", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Retry") { viewModel.retry() }
                }
            }
        }
    }
}

