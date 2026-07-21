//
//  NetworkMonitor.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//

import Foundation
import Network
import Observation

@MainActor
@Observable
final class NetworkMonitor {
    var hasNetworkConnection = true

    private let networkMonitor = NWPathMonitor()

    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.hasNetworkConnection = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "com.malcolm.stackoverflowsearch"))
    }

    deinit {
        networkMonitor.cancel()
    }
}
