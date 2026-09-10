import Foundation
import JackpotForms

public struct AppSettings: Codable, Equatable, Sendable {
    public var devConfig: DevConfig?

    public init(devConfig: DevConfig? = nil) {
        self.devConfig = devConfig
    }
}

public struct DevConfig: Codable, Equatable, Sendable {
    public var passwordReg: PasswordStrength?
    public var regionPasswordSuggestions: [PasswordSuggestion]?
    public var passwordLength: PasswordLength?
    public var passwordRegex: String?

    public init(passwordReg: PasswordStrength? = nil,
                regionPasswordSuggestions: [PasswordSuggestion]? = nil,
                passwordLength: PasswordLength? = nil,
                passwordRegex: String? = nil) {
        self.passwordReg = passwordReg
        self.regionPasswordSuggestions = regionPasswordSuggestions
        self.passwordLength = passwordLength
        self.passwordRegex = passwordRegex
    }
}

public struct PasswordStrength: Codable, Equatable, Sendable {
    public var medium: String?
    public var strong: String?

    public init(medium: String? = nil, strong: String? = nil) {
        self.medium = medium
        self.strong = strong
    }
}

public struct PasswordLength: Codable, Equatable, Sendable {
    public var minimum: Int?
    public var maximum: Int?

    public init(minimum: Int? = nil, maximum: Int? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct PasswordSuggestion: Codable, Equatable, Sendable {
    public var min: Int?
    public var max: Int?
    public var vulnerable: Bool?
    public var spaces: Bool?
    public var required: [PasswordCharacterClass]?

    public init(min: Int? = nil,
                max: Int? = nil,
                vulnerable: Bool? = nil,
                spaces: Bool? = nil,
                required: [PasswordCharacterClass]? = nil) {
        self.min = min
        self.max = max
        self.vulnerable = vulnerable
        self.spaces = spaces
        self.required = required
    }
}

public extension PasswordSuggestions.Config {
    init(_ dev: DevConfig?) {
        if let suggestions = dev?.regionPasswordSuggestions, !suggestions.isEmpty {
            self.init(
                min: suggestions.compactMap(\.min).first,
                max: suggestions.compactMap(\.max).first,
                vulnerable: suggestions.contains { $0.vulnerable == true },
                spaces: suggestions.contains { $0.spaces == true },
                required: Set(suggestions.flatMap { $0.required ?? [] })
            )
        } else {
            self.init(
                min: dev?.passwordLength?.minimum,
                max: dev?.passwordLength?.maximum,
                vulnerable: false,
                spaces: false,
                required: []
            )
        }
    }
}
