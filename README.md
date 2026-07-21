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

## Screenshots

*Search Screen*
| Light Mode | Dark Mode | 
| --- | --- | 
| <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 16 55" src="https://github.com/user-attachments/assets/49c81e5c-2e22-43a2-8cd5-819487a46590" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 17 02" src="https://github.com/user-attachments/assets/3227a32b-acc1-40bb-be12-87f1aed1979b" /> |

*Question Screen*
| Light Mode | Dark Mode | 
| --- | --- | 
|<img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 18 09" src="https://github.com/user-attachments/assets/f44ca871-30f8-4fe1-b322-16ae460b17c8" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 18 14" src="https://github.com/user-attachments/assets/64153228-e520-424c-b257-ae4015664ec4" /> |

*Error States*
| No Results | No Connection | Network Error | 
| --- | --- | --- | 
| <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 18 23" src="https://github.com/user-attachments/assets/07706796-cc6a-4f5d-a1f7-55e659295722" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 34 37" src="https://github.com/user-attachments/assets/bb050085-4d37-44b9-be26-ba07ae9ec95e" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-07-21 at 12 19 17" src="https://github.com/user-attachments/assets/88e9663f-8c55-42d4-b447-089061e6313d" /> |

## Demo
<video src="https://github.com/user-attachments/assets/b9d4cf0a-2062-49a5-8d7d-b3be0230a7f6" />





