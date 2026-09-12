import AuthenticationServices
import CryptoKit
import Foundation
import Security
#if os(iOS)
import UIKit
#endif

struct SupabaseSession: Codable, Hashable {
    var accessToken: String
    var refreshToken: String?
    var userID: String?
    var expiresAt: Date?
}

struct AccountDeletionStatus: Equatable {
    var pending = false
    var restoreUntil: Date?
    var deleted = false
}

struct SupabaseIdentityInfo: Decodable, Identifiable, Equatable {
    var identityID: String
    var provider: String
    var email: String?

    var id: String { identityID }

    private enum CodingKeys: String, CodingKey {
        case id
        case identityID = "identity_id"
        case provider
        case identityData = "identity_data"
    }

    private struct IdentityData: Decodable {
        var email: String?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedIdentityID = try container.decodeIfPresent(String.self, forKey: .identityID) {
            identityID = decodedIdentityID
        } else {
            identityID = try container.decode(String.self, forKey: .id)
        }
        provider = (try? container.decode(String.self, forKey: .provider)) ?? "unknown"
        email = (try? container.decode(IdentityData.self, forKey: .identityData))?.email
    }
}

struct SupabaseAccountInfo: Decodable, Equatable {
    var email: String?
    var identities: [SupabaseIdentityInfo]

    private enum CodingKeys: String, CodingKey {
        case email, identities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        email = try? container.decode(String.self, forKey: .email)
        identities = (try? container.decode([SupabaseIdentityInfo].self, forKey: .identities)) ?? []
    }
}

@MainActor
final class SupabaseService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = SupabaseService()
    private(set) var session: SupabaseSession?
    private var webSession: ASWebAuthenticationSession?

    var enabled: Bool {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "ACCOUNTS_ENABLED") as? String else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on": return true
        default: return false
        }
    }
    var configured: Bool { enabled && baseURL != nil && !publishableKey.isEmpty }
    private var baseURL: URL? { (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String).flatMap(URL.init(string:)) }
    private var publishableKey: String { Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String ?? "" }
    private let redirect = "planning://auth/callback"

    override init() { super.init(); session = loadSession() }

    func signInWithOAuth(provider: String) async -> Bool {
        guard let baseURL, configured else { return false }
        var components = URLComponents(url: baseURL.appending(path: "auth/v1/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "provider", value: provider), URLQueryItem(name: "redirect_to", value: redirect)]
        guard let url = components.url else { return false }
        return await withCheckedContinuation { continuation in
            let auth = ASWebAuthenticationSession(url: url, callbackURLScheme: "planning") { [weak self] callback, _ in
                guard let self, let callback, let parsed = self.parseSession(from: callback) else { continuation.resume(returning: false); return }
                self.session = parsed; self.saveSession(parsed); continuation.resume(returning: true)
            }
            auth.presentationContextProvider = self; auth.prefersEphemeralWebBrowserSession = false; self.webSession = auth
            if !auth.start() { continuation.resume(returning: false) }
        }
    }

    func sendEmailOTP(email: String) async -> Bool {
        guard let baseURL, configured else { return false }
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/otp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addKey(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "create_user": true
        ])
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return 200..<300 ~= http.statusCode
    }

    func verifyEmailOTP(email: String, token: String) async -> Bool {
        guard let baseURL, configured else { return false }
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/verify"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addKey(&request)
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "token": token,
            "type": "email"
        ])
        guard let (raw, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode,
              let decoded = try? JSONDecoder().decode(RefreshResponse.self, from: raw) else { return false }
        let verified = SupabaseSession(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            userID: decoded.user?.id ?? jwtSubject(decoded.accessToken),
            expiresAt: decoded.expiresIn.map { Date().addingTimeInterval($0) }
        )
        session = verified
        saveSession(verified)
        return true
    }

    // Kept for compatibility with older UI call sites. The release UI now uses a 6-digit email OTP.
    func sendMagicLink(email: String) async -> Bool {
        await sendEmailOTP(email: email)
    }

    func accountInfo() async -> SupabaseAccountInfo? {
        guard let session = await validSession(), let baseURL else { return nil }
        var request = URLRequest(url: baseURL.appending(path: "auth/v1/user"))
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        guard let (raw, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode else { return nil }
        return try? JSONDecoder().decode(SupabaseAccountInfo.self, from: raw)
    }

    func linkIdentity(provider: String) async -> Bool {
        guard let session = await validSession(), let baseURL else { return false }
        var components = URLComponents(url: baseURL.appending(path: "auth/v1/user/identities/authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "redirect_to", value: redirect),
            URLQueryItem(name: "skip_http_redirect", value: "true")
        ]
        guard let url = components.url else { return false }

        var request = URLRequest(url: url)
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        guard let (raw, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              200..<300 ~= http.statusCode,
              let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let providerURLString = json["url"] as? String,
              let providerURL = URL(string: providerURLString) else { return false }

        return await withCheckedContinuation { continuation in
            let auth = ASWebAuthenticationSession(url: providerURL, callbackURLScheme: "planning") { [weak self] callback, error in
                guard let self else { continuation.resume(returning: false); return }
                self.webSession = nil
                guard error == nil, let callback else { continuation.resume(returning: false); return }
                continuation.resume(returning: !self.callbackContainsAuthError(callback))
            }
            auth.presentationContextProvider = self
            auth.prefersEphemeralWebBrowserSession = false
            self.webSession = auth
            if !auth.start() {
                self.webSession = nil
                continuation.resume(returning: false)
            }
        }
    }

    func unlinkIdentity(_ identity: SupabaseIdentityInfo) async -> Bool {
        guard let session = await validSession(), let baseURL else { return false }
        let identities = await accountInfo()?.identities ?? []
        guard identities.count >= 2 else { return false }
        let url = baseURL.appending(path: "auth/v1/user/identities/\(identity.identityID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return 200..<300 ~= http.statusCode
    }

    func handle(url: URL) -> Bool {
        guard let parsed = parseSession(from: url) else { return false }
        session = parsed; saveSession(parsed); return true
    }

    func signOut() { session = nil; deleteKeychain("supabase-session") }

    func accountDeletionStatus() async -> AccountDeletionStatus {
        await accountAction("status") ?? AccountDeletionStatus()
    }

    func requestAccountDeletion() async -> AccountDeletionStatus? {
        await accountAction("request_delete")
    }

    func restoreAccount() async -> AccountDeletionStatus? {
        await accountAction("restore")
    }

    func deleteCloudSnapshot() async -> Bool {
        guard let session = await validSession(), let uid = session.userID, let baseURL else { return false }
        var components = URLComponents(url: baseURL.appending(path: "rest/v1/app_snapshots"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(uid)")]
        guard let url = components.url else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return 200..<300 ~= http.statusCode
    }

    private struct AccountActionResponse: Decodable {
        var pending: Bool?
        var restoreUntil: String?
        var deleted: Bool?
        var restored: Bool?

        enum CodingKeys: String, CodingKey {
            case pending, deleted, restored
            case restoreUntil = "restore_until"
        }
    }

    private func accountAction(_ action: String) async -> AccountDeletionStatus? {
        guard let session = await validSession(), let baseURL else { return nil }
        let url = baseURL.appending(path: "functions/v1/account-management")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["action": action])
        guard let (raw, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300 ~= http.statusCode || http.statusCode == 410),
              let decoded = try? JSONDecoder().decode(AccountActionResponse.self, from: raw) else { return nil }
        let deadline = decoded.restoreUntil.flatMap { ISO8601DateFormatter().date(from: $0) }
        if decoded.deleted == true {
            signOut()
            return AccountDeletionStatus(pending: false, restoreUntil: nil, deleted: true)
        }
        return AccountDeletionStatus(pending: decoded.pending ?? false, restoreUntil: deadline, deleted: false)
    }

    func loadSnapshot() async -> AppData? {
        guard let session = await validSession(), let uid = session.userID, let baseURL else { return nil }
        var c = URLComponents(url: baseURL.appending(path: "rest/v1/app_snapshots"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(uid)"), URLQueryItem(name: "select", value: "data")]
        guard let url = c.url else { return nil }
        var request = URLRequest(url: url); addKey(&request); request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        guard let (raw, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let rows = try? JSONSerialization.jsonObject(with: raw) as? [[String: Any]], let payload = rows.first?["data"], JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload), let decoded = try? JSONDecoder().decode(AppData.self, from: data) else { return nil }
        return decoded
    }

    func saveSnapshot(_ data: AppData) async -> Bool {
        guard let session = await validSession(), let uid = session.userID, let baseURL else { return false }
        var request = URLRequest(url: baseURL.appending(path: "rest/v1/app_snapshots")); request.httpMethod = "POST"; addKey(&request); request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        guard let encoded = try? JSONEncoder().encode(data), let json = try? JSONSerialization.jsonObject(with: encoded) else { return false }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["user_id": uid, "data": json, "updated_at": ISO8601DateFormatter().string(from: .now)])
        guard let (_, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else { return false }
        return 200..<300 ~= http.statusCode
    }

    private struct RefreshResponse: Decodable {
        struct User: Decodable { var id: String? }
        var accessToken: String
        var refreshToken: String?
        var expiresIn: Double?
        var user: User?
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    private func validSession() async -> SupabaseSession? {
        guard let current = session else { return nil }
        if let expiry = current.expiresAt, expiry.timeIntervalSinceNow > 120 { return current }
        guard let refreshToken = current.refreshToken, let baseURL else { return current.expiresAt == nil ? current : nil }

        var components = URLComponents(url: baseURL.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        guard let (raw, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let decoded = try? JSONDecoder().decode(RefreshResponse.self, from: raw) else {
            return current.expiresAt == nil ? current : nil
        }
        let refreshed = SupabaseSession(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken ?? refreshToken,
            userID: decoded.user?.id ?? current.userID ?? jwtSubject(decoded.accessToken),
            expiresAt: decoded.expiresIn.map { Date().addingTimeInterval($0) }
        )
        session = refreshed
        saveSession(refreshed)
        return refreshed
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        return UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) }.first ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }

    private func callbackContainsAuthError(_ url: URL) -> Bool {
        let raw = [url.query ?? "", url.fragment ?? ""].joined(separator: "&").lowercased()
        return raw.contains("error=") || raw.contains("error_description=")
    }

    private func parseSession(from url: URL) -> SupabaseSession? {
        let fragment = url.fragment ?? ""; let query = url.query ?? ""; let raw = [query, fragment].filter { !$0.isEmpty }.joined(separator: "&")
        var values: [String: String] = [:]
        for pair in raw.split(separator: "&") { let parts = pair.split(separator: "=", maxSplits: 1).map(String.init); if parts.count == 2 { values[parts[0]] = parts[1].removingPercentEncoding ?? parts[1] } }
        guard let access = values["access_token"] else { return nil }
        let userID = jwtSubject(access); let expires = values["expires_in"].flatMap(Double.init).map { Date().addingTimeInterval($0) }
        return SupabaseSession(accessToken: access, refreshToken: values["refresh_token"], userID: userID, expiresAt: expires)
    }

    private func jwtSubject(_ token: String) -> String? {
        let parts = token.split(separator: "."); guard parts.count > 1 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["sub"] as? String
    }

    private func addKey(_ request: inout URLRequest) {
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        // Legacy anon JWT keys may also be used as a Bearer token. Modern sb_publishable_ keys must stay in the apikey header.
        if publishableKey.split(separator: ".").count == 3 {
            request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        }
    }
    private func saveSession(_ session: SupabaseSession) { if let data = try? JSONEncoder().encode(session) { saveKeychain("supabase-session", data: data) } }
    private func loadSession() -> SupabaseSession? { guard let data = loadKeychain("supabase-session") else { return nil }; return try? JSONDecoder().decode(SupabaseSession.self, from: data) }
    private func saveKeychain(_ key: String, data: Data) { deleteKeychain(key); let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]; SecItemAdd(q as CFDictionary, nil) }
    private func loadKeychain(_ key: String) -> Data? { let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]; var result: CFTypeRef?; return SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess ? result as? Data : nil }
    private func deleteKeychain(_ key: String) { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary) }
}
