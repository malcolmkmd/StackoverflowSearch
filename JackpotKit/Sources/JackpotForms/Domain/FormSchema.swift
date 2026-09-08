import Foundation

/// A form as the CRM describes it: a section is one page, and fields sharing a row sit side by side.
public struct FormSchema: Identifiable, Equatable, Sendable {
    public let id: Int
    public let codeName: FormName
    public let sections: [FormSection]

    public init(id: Int, codeName: FormName, sections: [FormSection]) {
        self.id = id
        self.codeName = codeName
        self.sections = sections
    }

    public var allFields: [FormField] {
        sections.flatMap(\.fields)
    }

    public func field(identifiedBy identifier: String) -> FormField? {
        allFields.first { $0.identifier == identifier }
    }
}

public struct FormSection: Identifiable, Equatable, Sendable {
    public let id: Int
    public let rows: [FormRow]

    public init(id: Int, rows: [FormRow]) {
        self.id = id
        self.rows = rows
    }

    public var fields: [FormField] { rows.flatMap(\.fields) }
}

public struct FormRow: Identifiable, Equatable, Sendable {
    public let number: Int
    public let fields: [FormField]

    public var id: Int { number }

    public init(number: Int, fields: [FormField]) {
        self.number = number
        self.fields = fields
    }
}
