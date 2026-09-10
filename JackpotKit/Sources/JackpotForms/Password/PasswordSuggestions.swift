import Foundation
import JackpotUI

public enum PasswordSuggestions {
    public struct Config: Sendable, Equatable {
        public var min: Int?
        public var max: Int?
        public var vulnerable: Bool
        public var spaces: Bool
        public var required: Set<PasswordCharacterClass>

        public init(min: Int? = nil,
                    max: Int? = nil,
                    vulnerable: Bool = false,
                    spaces: Bool = false,
                    required: Set<PasswordCharacterClass> = []) {
            self.min = min
            self.max = max
            self.vulnerable = vulnerable
            self.spaces = spaces
            self.required = required
        }
    }

    public static func items(for value: String,
                              config: Config,
                              translate: (String) -> String) -> [JackpotChecklistItem] {
        var items: [JackpotChecklistItem] = []
        if let n = config.min {
            items.append(.init(id: "min",
                                text: translate("min-\(n)-char"),
                                isSatisfied: value.count >= n))
        }
        if let n = config.max {
            items.append(.init(id: "max",
                                text: translate("max-\(n)-char"),
                                isSatisfied: !value.isEmpty && value.count <= n))
        }
        if config.vulnerable {
            items.append(.init(id: "vulnerable",
                                text: translate("password-is-vulnerable"),
                                isSatisfied: value.range(of: "password", options: .caseInsensitive) == nil))
        }
        if config.spaces {
            items.append(.init(id: "spaces",
                                text: translate("please-remove-spaces"),
                                isSatisfied: value.rangeOfCharacter(from: .whitespaces) == nil))
        }
        for cls in [PasswordCharacterClass.upper, .lower, .number, .special] where config.required.contains(cls) {
            items.append(cls.checklistItem(for: value, translate: translate))
        }
        return items
    }
}

public enum PasswordCharacterClass: String, Codable, Sendable {
    case upper, lower, number, special
}

extension PasswordCharacterClass {
    var translationKey: String {
        switch self {
        case .upper:   return "at-least-one-upper-char"
        case .lower:   return "at-least-one-lower-char"
        case .number:  return "at-least-one-num-char"
        case .special: return "at-least-one-special-char"
        }
    }

    func isSatisfied(by value: String) -> Bool {
        switch self {
        case .upper:   return value.rangeOfCharacter(from: .uppercaseLetters) != nil
        case .lower:   return value.rangeOfCharacter(from: .lowercaseLetters) != nil
        case .number:  return value.rangeOfCharacter(from: .decimalDigits) != nil
        case .special: return value.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.whitespaces).inverted) != nil
        }
    }

    func checklistItem(for value: String, translate: (String) -> String) -> JackpotChecklistItem {
        JackpotChecklistItem(id: rawValue, text: translate(translationKey), isSatisfied: isSatisfied(by: value))
    }
}
