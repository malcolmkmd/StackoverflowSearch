import Foundation
import JackpotNetworking

/// The captured CRM payloads that ship with the package: the `registration` schema, the `locales`
/// slice that labels it, and the two submit envelopes. Previews, the sandbox and any build without
/// a backend run on these — through the shipping repository, never a second implementation.
public enum FormFixtures {
    /// The schema blob exactly as the CRM returned it. In the app this same shape arrives on
    /// app-data; here it is a file, which is the only difference.
    public static let registrationJSON: Data = json("registration")

    /// Empty only if the resource is missing or malformed, which `BundledFormsTests` rules out.
    public static let registrationSchema: FormSchema =
        (try? FormSchema(json: registrationJSON)) ?? FormSchema(id: 0, codeName: .registration, sections: [])

    /// Stands in for the app's `getTranslation`: same contract, the key back on a miss.
    public static let translate: @Sendable (String) -> String = { locales[$0.lowercased()] ?? $0 }

    /// The `idNumber` the bundled CRM rejects. Thirteen digits, so it clears the field's own rule
    /// and the form can actually be submitted — which is what makes the failure path reachable.
    public static let rejectedIdNumber = "0000000000000"

    static let locales: [String: String] =
        (try? JSONDecoder().decode([String: String].self, from: json("locales"))) ?? [:]

    static func json(_ resource: String) -> Data {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return Data() }
        return data
    }
}

public extension FormDependencies {
    /// The live composition over bundled bytes: real endpoints, real envelope decoding, real error
    /// mapping, with `BundledHTTPClient` in place of the network. Submitting
    /// `FormFixtures.rejectedIdNumber` returns the CRM's rejection envelope, so both outcomes are
    /// demoable offline.
    ///
    /// - Parameter delay: Latency on submit, so the button's in-flight state is visible.
    static func bundled(delay: TimeInterval = 0.35) -> FormDependencies {
        let accepted = BundledHTTPClient.Fixture(resource: "submit-accepted", in: .module)
        let rejected = BundledHTTPClient.Fixture(resource: "submit-rejected", in: .module)
        let transport = BundledHTTPClient(latency: delay) { request in
            let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
            return body.contains("\"idNumber\":\"\(FormFixtures.rejectedIdNumber)\"") ? rejected : accepted
        }
        return live(
            form: FormFixtures.registrationSchema,
            baseURL: URL(string: "https://config.jpc.africa")!,
            httpClient: transport,
            translate: FormFixtures.translate,
            // The captured schema carries no recaptcha row, so nothing asks for a token.
            recaptcha: { _ in nil }
        )
    }
}
