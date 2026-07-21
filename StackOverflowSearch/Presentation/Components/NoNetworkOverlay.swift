//
//  NoNetworkOverlay.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//
import SwiftUI

struct NoNetworkOverlay: ViewModifier {
    let networkMonitor: NetworkMonitor

    @State private var isDismissed = false

    private var isVisible: Bool {
        !networkMonitor.hasNetworkConnection && !isDismissed
    }

    func body(content: Content) -> some View {
        content
            .disabled(isVisible)
            .overlay {
                if isVisible {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundStyle(Theme.orange)
                            Text("No Internet Connection")
                                .font(.headline)
                            Text("Please check your network settings and try again.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("OK") { isDismissed = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.orange)
                        }
                        .padding(24)
                        .frame(maxWidth: 320)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding()
                    }
                }
            }
            .onChange(of: networkMonitor.hasNetworkConnection) { _, connected in
                if connected {
                    isDismissed = false
                }
            }
    }
}

extension View {
    func noNetworkOverlay(monitor: NetworkMonitor) -> some View {
        modifier(NoNetworkOverlay(networkMonitor: monitor))
    }
}
