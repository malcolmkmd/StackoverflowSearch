import Foundation
import JackpotNetworking
import JackpotFormsDomain

/// GET {base}/forms/{brand}/{region}/{formCodeName}?api-version=2.0
///
/// The ticket's example call is
/// `https://config.jpc.africa/crm/forms/jackpotcity/JZA/registration?api-version=2.0`,
/// so brand and region are path components and the version is an environment-wide
/// query item (see `APIEnvironment.crm(baseURL:)` in this target).
public struct FormRequest: APIEndpoint {
    let brand: String
    let region: String
    let formName: FormName

    public init(brand: String, region: String, formName: FormName) {
        self.brand = brand
        self.region = region
        self.formName = formName
    }

    public var path: String { "forms/\(brand)/\(region)/\(formName.rawValue)" }
    public var method: HTTPMethod { .GET }
}

