import Foundation

/// Where the cloud copy lives. The anon key is public by design: every table is locked to its owner
/// by row-level security (supabase/migrations), so the key alone reads nothing.
struct CloudConfig: Sendable, Equatable {
    let url: URL
    let anonKey: String

    /// Fill these in from the Supabase project (Settings → API). Empty means cloud backup is off in this build.
    static let projectURL = ""
    static let projectAnonKey = ""

    static var current: CloudConfig? {
        guard !projectAnonKey.isEmpty, let url = URL(string: projectURL) else { return nil }
        return CloudConfig(url: url, anonKey: projectAnonKey)
    }
}

/// A signed-in Supabase session. Kept in the Keychain.
struct CloudSession: Codable, Sendable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String

    func isExpired(now: Date = .now) -> Bool {
        expiresAt.timeIntervalSince(now) < 60
    }
}

enum CloudError: Error, Equatable, LocalizedError {
    case http(status: Int, message: String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .http(let status, let message): String(localized: "The cloud answered \(status): \(message)")
        case .badResponse: String(localized: "The cloud sent an answer Kinledger could not read.")
        }
    }

    /// The session is no longer valid and the person needs to sign in again.
    var needsSignIn: Bool {
        if case .http(let status, _) = self { return status == 401 }
        return false
    }
}

/// Sends HTTP requests. Swapped for a fake in tests.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudError.badResponse }
        return (data, http)
    }
}

/// A small client for the parts of Supabase Kinledger uses: auth, two tables and receipt storage.
/// Plain HTTP keeps the app free of a large SDK and makes every request testable.
struct CloudClient: Sendable {
    let config: CloudConfig
    let transport: any HTTPTransport

    init(config: CloudConfig, transport: any HTTPTransport = URLSessionTransport()) {
        self.config = config
        self.transport = transport
    }

    // MARK: Auth

    /// Exchanges an Apple identity token for a Supabase session. `nonce` is the raw nonce whose
    /// SHA-256 was given to Apple.
    func signInWithApple(idToken: String, nonce: String, now: Date = .now) async throws -> CloudSession {
        let body = try JSONSerialization.data(withJSONObject: ["provider": "apple", "id_token": idToken, "nonce": nonce])
        return try await tokenRequest(grantType: "id_token", body: body, now: now)
    }

    func refresh(_ session: CloudSession, now: Date = .now) async throws -> CloudSession {
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": session.refreshToken])
        return try await tokenRequest(grantType: "refresh_token", body: body, now: now)
    }

    private func tokenRequest(grantType: String, body: Data, now: Date) async throws -> CloudSession {
        var request = makeRequest(path: "auth/v1/token", query: [URLQueryItem(name: "grant_type", value: grantType)], session: nil)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let data = try await send(request)
        struct TokenResponse: Decodable {
            struct User: Decodable { let id: String }
            let access_token: String
            let refresh_token: String
            let expires_in: Double
            let user: User
        }
        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else { throw CloudError.badResponse }
        return CloudSession(
            accessToken: token.access_token,
            refreshToken: token.refresh_token,
            expiresAt: now.addingTimeInterval(token.expires_in),
            userID: token.user.id
        )
    }

    // MARK: Entries

    /// Uploads entries. Retrying the same batch is safe: rows are keyed by the entry's own id.
    func upsert(_ items: [CloudEntry], session: CloudSession) async throws {
        guard !items.isEmpty else { return }
        let encoder = CloudCodec.encoder()
        let rows: [[String: Any]] = try items.map { item in
            let payload = try JSONSerialization.jsonObject(with: encoder.encode(item))
            var row: [String: Any] = [
                "id": item.id.uuidString.lowercased(),
                "payload": payload,
                "updated_at": CloudCodec.format(item.updatedAt),
            ]
            row["deleted_at"] = item.deletedAt.map(CloudCodec.format) ?? NSNull()
            return row
        }
        var request = makeRequest(path: "rest/v1/entries", session: session)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: rows)
        _ = try await send(request)
    }

    /// Entries changed in the cloud after `cursor`, in the order they changed.
    func changes(after cursor: String?, limit: Int = 500, session: CloudSession) async throws -> [RemoteChange] {
        var query = [
            URLQueryItem(name: "select", value: "payload,changed_at"),
            URLQueryItem(name: "order", value: "changed_at.asc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "changed_at", value: "gt.\(cursor)"))
        }
        var request = makeRequest(path: "rest/v1/entries", query: query, session: session)
        request.httpMethod = "GET"
        let data = try await send(request)
        struct Row: Decodable {
            let payload: CloudEntry
            let changed_at: String
        }
        guard let rows = try? CloudCodec.decoder().decode([Row].self, from: data) else { throw CloudError.badResponse }
        return rows.map { RemoteChange(item: $0.payload, changedAt: $0.changed_at) }
    }

    // MARK: Profile

    func upsertProfile(_ profile: CloudProfile, session: CloudSession) async throws {
        let payload = try JSONSerialization.jsonObject(with: CloudCodec.encoder().encode(profile))
        let row: [String: Any] = ["owner_id": session.userID, "payload": payload, "updated_at": CloudCodec.format(profile.updatedAt)]
        var request = makeRequest(path: "rest/v1/profiles", session: session)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [row])
        _ = try await send(request)
    }

    func fetchProfile(session: CloudSession) async throws -> CloudProfile? {
        var request = makeRequest(path: "rest/v1/profiles", query: [URLQueryItem(name: "select", value: "payload")], session: session)
        request.httpMethod = "GET"
        let data = try await send(request)
        struct Row: Decodable { let payload: CloudProfile }
        guard let rows = try? CloudCodec.decoder().decode([Row].self, from: data) else { throw CloudError.badResponse }
        return rows.first?.payload
    }

    // MARK: Receipts

    /// Receipt photos live under the owner's folder in a private bucket.
    func receiptPath(_ name: String, session: CloudSession) -> String {
        "storage/v1/object/receipts/\(session.userID)/\(name)"
    }

    func uploadReceipt(_ name: String, data: Data, session: CloudSession) async throws {
        var request = makeRequest(path: receiptPath(name, session: session), session: session)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = data
        _ = try await send(request)
    }

    func downloadReceipt(_ name: String, session: CloudSession) async throws -> Data {
        var request = makeRequest(path: receiptPath(name, session: session), session: session)
        request.httpMethod = "GET"
        return try await send(request)
    }

    // MARK: Report links

    func createReportLink(_ link: ReportLink, session: CloudSession) async throws {
        let row: [String: Any] = [
            "token": link.token,
            "period_start": CloudCodec.format(link.periodStart),
            "period_end": CloudCodec.format(link.periodEnd),
            "include_notes": link.includeNotes,
        ]
        var request = makeRequest(path: "rest/v1/report_links", session: session)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: [row])
        _ = try await send(request)
    }

    /// Turns off every link this person has shared. The reports stop loading at once.
    func revokeAllReportLinks(session: CloudSession, now: Date = .now) async throws {
        var request = makeRequest(
            path: "rest/v1/report_links",
            query: [URLQueryItem(name: "revoked_at", value: "is.null")],
            session: session
        )
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["revoked_at": CloudCodec.format(now)])
        _ = try await send(request)
    }

    // MARK: Account

    /// Deletes the cloud account and everything in it. `authorizationCode` comes from a fresh
    /// Sign in with Apple, so the server can revoke the Apple tokens as the App Store requires.
    func deleteAccount(authorizationCode: String, session: CloudSession) async throws {
        var request = makeRequest(path: "functions/v1/delete-account", session: session)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["authorization_code": authorizationCode])
        _ = try await send(request)
    }

    // MARK: Plumbing

    func makeRequest(path: String, query: [URLQueryItem] = [], session: CloudSession?) -> URLRequest {
        var components = URLComponents(url: config.url.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query
            // "+" in a timestamp cursor must not turn into a space on the server.
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session?.accessToken ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let message = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw CloudError.http(status: response.statusCode, message: message)
        }
        return data
    }
}
