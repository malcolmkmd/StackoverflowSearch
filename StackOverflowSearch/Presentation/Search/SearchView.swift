//
//  SearchView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/19.
//

import SwiftUI
import JackpotUI

struct SearchView: View {
    
    @State private var viewModel: SearchViewModel
    @State private var showsRegistration = false
    private let questionRepository: QuestionRepository
    
    init(questionRepository: any QuestionRepository) {
        self.questionRepository = questionRepository
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
                    QuestionDetailView(
                        question: question,
                        questionRepository: questionRepository
                    )
                }
            }
        }
        // The way the app presents its panels: over the page, not a system sheet. The inset is
        // the header's height, so the header stays visible, dimmed, above the panel.
        .jackpotPopup(isPresented: $showsRegistration, topInset: 60) {
            RegistrationSandbox(onClose: { showsRegistration = false })
        }
        .task {
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
                    .scaledToFit()
                    .frame(width: 200, height: 40)
                    .foregroundStyle(Theme.orange)
            }
            Spacer()
            // Occupies the slot that balanced the logo, so the logo stays centred.
            Button {
                showsRegistration = true
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 22, height: 22)
            }
            .accessibilityLabel("Open the sign-up form sandbox")
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
        .scrollDismissesKeyboard(.immediately)
        .isNearBottom {
            viewModel.prefetchNextPageIfNeeded()
        }
        .overlay(alignment: .center) {
            switch viewModel.viewState {
            case .loading:
                List {
                    ForEach(0..<8, id: \.self) { _ in
                        SearchRowSkeleton()
                            .listRowSeparator(.hidden)
                    }
                }
                .scrollDisabled(true)
                .listStyle(.plain)
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
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

