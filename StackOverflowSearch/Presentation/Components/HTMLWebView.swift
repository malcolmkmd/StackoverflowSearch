//
//  HTMLWebView.swift
//  StackOverflowSearch
//
//  Created by Malcolm Collin on 2026/07/21.
//
import UIKit
import SwiftUI
import WebKit

struct HTMLWebView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat
    var onContentReady: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, onContentReady: onContentReady)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.load(html: html, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.height = $height
        context.coordinator.onContentReady = onContentReady
        if context.coordinator.lastHTML != html {
            context.coordinator.load(html: html, in: webView)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var height: Binding<CGFloat>
        var onContentReady: (() -> Void)?
        var lastHTML: String?

        init(height: Binding<CGFloat>, onContentReady: (() -> Void)?) {
            self.height = height
            self.onContentReady = onContentReady
        }

        func load(html: String, in webView: WKWebView) {
            lastHTML = html
            webView.loadHTMLString(Self.wrappedHTML(html), baseURL: URL(string: "https://stackoverflow.com"))
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { [weak self] result, _ in
                guard let self else { return }
                let measured = max(CGFloat((result as? NSNumber)?.doubleValue ?? 1), 1)
                DispatchQueue.main.async {
                    self.height.wrappedValue = measured
                    self.onContentReady?()
                }
            }
        }

        static func wrappedHTML(_ body: String) -> String {
            """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
            <style>
              :root { color-scheme: light dark; }
              img, svg { max-width: 100%; height: auto; }
            </style>
            </head>
            <body>\(body)</body>
            </html>
            """
        }
    }
}
