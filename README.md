# StackOverflowSearch

A SwiftUI app for searching Stack Overflow questions via the Stack Exchange API

## How to Build

1. Open `StackOverflowSearch.xcodeproj` in Xcode.
2. Select an iOS simulator and run (Cmd+R).
3. Run tests with Cmd+U.

## Architecture

MVVM with clean architecture split:

- **Core/Networking** — protocol-based API client (`HTTPClient`, `ApiClient`), typed endpoints, and error handling.
- **Data** — DTOs, mappers, and repository implementations that talk to the network layer.
- **Domain** — plain entities and repository protocols.
- **Presentation** — SwiftUI views and view models & shared components.

Dependencies are wired in `AppDependencies` and injected through initializers.

## Demo

