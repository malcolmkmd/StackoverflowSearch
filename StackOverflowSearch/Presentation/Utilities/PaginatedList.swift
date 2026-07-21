//
//  PaginatedList.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//
import SwiftUI

@MainActor
@Observable
final class PaginatedList<Item: Identifiable & Equatable & Sendable> {
    enum ViewState {
        case loading
        case loaded([Item])
        case failed(String)
    }
    
    typealias PageProvider = @Sendable (_ page: Int) async throws -> Page<Item>
    
    private(set) var viewState: ViewState = .loading
    private(set) var hasMorePages = false
    private(set) var isPrefetching =  false
    
    var items: [Item] {
        guard case .loaded(let items) = viewState else {
            return []
        }
        return items
    }
    
    @ObservationIgnored private var currentPage = 1
    @ObservationIgnored private var provider: PageProvider?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?
    
    func load(delayNanoseconds: UInt64 = 0, using provider: @escaping PageProvider) {
        self.provider = provider
        cancel()
        currentPage = 1
        hasMorePages = false
        isPrefetching = false

        if delayNanoseconds == 0 {
            viewState = .loading
        }

        loadTask = Task { [weak self] in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            guard let self, !Task.isCancelled else { return }
            self.viewState = .loading

            do {
                let page = try await provider(1)
                guard !Task.isCancelled else { return }
                self.viewState = .loaded(page.items)
                self.hasMorePages = page.hasMore
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self.viewState = .failed(("Something went wrong."))
            }
        }
    }
    
    func prefetchNextPage() {
        guard let provider, hasMorePages, !isPrefetching else { return }
        isPrefetching = true
        let nextPage = currentPage + 1

        prefetchTask = Task { [weak self] in
            do {
                let page = try await provider(nextPage)
                guard let self else { return }
                guard !Task.isCancelled, case .loaded(let existing) = self.viewState else {
                    self.isPrefetching = false
                    return
                }
                self.viewState = .loaded(Self.merge(existing, page.items))
                self.currentPage = nextPage
                self.hasMorePages = page.hasMore
                self.isPrefetching = false
            } catch {
                self?.isPrefetching = false
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        prefetchTask?.cancel()
    }

    private static func merge(_ existing: [Item], _ incoming: [Item]) -> [Item] {
        var merged = existing
        let existingIDs = Set(existing.map(\.id))
        merged.append(contentsOf: incoming.filter { !existingIDs.contains($0.id) })
        return merged
    }
    
}
