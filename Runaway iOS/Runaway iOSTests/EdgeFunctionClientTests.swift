import XCTest
@testable import Runaway_iOS

final class EdgeFunctionClientTests: XCTestCase {
    func testGatewayUnauthorizedBodyDecodesWithoutStructuredErrorEnvelope() {
        let data = Data(#"{"message":"Invalid JWT"}"#.utf8)

        let error = EdgeFunctionError.decode(statusCode: 401, data: data)

        XCTAssertEqual(error.statusCode, 401)
        XCTAssertEqual(error.code, "AUTH_REQUIRED")
        XCTAssertEqual(error.message, "Invalid JWT")
    }

    func testHandlerErrorEnvelopePreservesStableCodeAndMessage() {
        let data = Data(#"{"error":{"code":"ATHLETE_MISMATCH","message":"Requested athlete does not match authenticated user"}}"#.utf8)

        let error = EdgeFunctionError.decode(statusCode: 403, data: data)

        XCTAssertEqual(error.code, "ATHLETE_MISMATCH")
        XCTAssertEqual(error.message, "Requested athlete does not match authenticated user")
    }

    func testAuthenticatedInvokeUsesSessionJWTAndDecodesOAuthURL() async throws {
        let session = makeStubSession { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer session-jwt")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "publishable-key")
            XCTAssertEqual(request.url?.path, "/functions/v1/strava-auth")
            return (
                HTTPURLResponse(
                    url: request.url!, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!,
                Data(#"{"success":true,"authorization_url":"https://www.strava.com/oauth/authorize?state=opaque"}"#.utf8)
            )
        }
        let client = AuthenticatedEdgeFunctionClient(
            baseURL: URL(string: "https://example.supabase.co")!,
            apiKey: "publishable-key",
            session: session,
            accessToken: { "session-jwt" }
        )

        let response: OAuthInitiationResponse = try await client.invoke(
            "strava-auth",
            body: OAuthInitiationRequest()
        )

        XCTAssertEqual(
            response.authorizationURL,
            URL(string: "https://www.strava.com/oauth/authorize?state=opaque")
        )
    }
}

private func makeStubSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    EdgeURLProtocol.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [EdgeURLProtocol.self]
    return URLSession(configuration: configuration)
}

private final class EdgeURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
