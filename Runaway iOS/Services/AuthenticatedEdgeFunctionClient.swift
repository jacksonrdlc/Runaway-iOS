import Foundation

struct OAuthInitiationRequest: Encodable {
    let webRedirectURL: String?

    init(webRedirectURL: String? = nil) {
        self.webRedirectURL = webRedirectURL
    }

    enum CodingKeys: String, CodingKey {
        case webRedirectURL = "web_redirect_url"
    }
}

struct OAuthInitiationResponse: Decodable {
    let success: Bool
    let authorizationURLString: String?
    let error: String?
    let code: String?

    var authorizationURL: URL? {
        authorizationURLString.flatMap(URL.init(string:))
    }

    enum CodingKeys: String, CodingKey {
        case success
        case authorizationURLString = "authorization_url"
        case error
        case code
    }
}

struct EdgeFunctionError: Error, Equatable, LocalizedError {
    let statusCode: Int
    let code: String
    let message: String

    var errorDescription: String? { message }

    static func decode(statusCode: Int, data: Data) -> EdgeFunctionError {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let nestedError = json?["error"] as? [String: Any]
        let legacyError = json?["error"] as? String
        let message = nestedError?["message"] as? String
            ?? legacyError
            ?? json?["message"] as? String
            ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
        let explicitCode = nestedError?["code"] as? String ?? json?["code"] as? String
        let fallbackCode: String
        switch statusCode {
        case 401: fallbackCode = "AUTH_REQUIRED"
        case 403: fallbackCode = "FORBIDDEN"
        default: fallbackCode = "HTTP_\(statusCode)"
        }
        return EdgeFunctionError(
            statusCode: statusCode,
            code: explicitCode ?? fallbackCode,
            message: message
        )
    }
}

struct AuthenticatedEdgeFunctionClient {
    private let baseURL: URL?
    private let apiKey: String
    private let session: URLSession
    private let accessToken: () async throws -> String

    init(
        baseURL: URL?,
        apiKey: String,
        session: URLSession = .shared,
        accessToken: @escaping () async throws -> String
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.accessToken = accessToken
    }

    static var live: AuthenticatedEdgeFunctionClient {
        AuthenticatedEdgeFunctionClient(
            baseURL: SupabaseConfiguration.supabaseURL.flatMap(URL.init(string:)),
            apiKey: SupabaseConfiguration.supabaseKey ?? "",
            accessToken: { try await supabase.auth.session.accessToken }
        )
    }

    func invoke<Response: Decodable, Body: Encodable>(
        _ functionName: String,
        body: Body
    ) async throws -> Response {
        guard let baseURL, !apiKey.isEmpty else {
            throw EdgeFunctionError(
                statusCode: 0,
                code: "CLIENT_CONFIGURATION_ERROR",
                message: "Runaway is not configured to contact the server"
            )
        }

        let token = try await accessToken()
        guard !token.isEmpty else {
            throw EdgeFunctionError(
                statusCode: 401,
                code: "AUTH_REQUIRED",
                message: "Please sign in again"
            )
        }

        let url = baseURL
            .appending(path: "functions")
            .appending(path: "v1")
            .appending(path: functionName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EdgeFunctionError(
                statusCode: 0,
                code: "INVALID_RESPONSE",
                message: "The server returned an invalid response"
            )
        }
        guard 200...299 ~= httpResponse.statusCode else {
            throw EdgeFunctionError.decode(statusCode: httpResponse.statusCode, data: data)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
