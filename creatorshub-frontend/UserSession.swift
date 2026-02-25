import Foundation
import Combine

/// Holds the authenticated user + tokens and persists them via the Keychain.
final class UserSession: ObservableObject {
    static let shared = UserSession()

    @Published var currentUser: User?
    @Published var accessToken: String?
    @Published var refreshToken: String?

    private let accessTokenService = "creatorshub.accessToken"
    private let refreshTokenService = "creatorshub.refreshToken"
    private let userService = "creatorshub.user"
    private let account = "currentUser"

    private init() {
        if let tokenData = KeychainHelper.standard.read(service: accessTokenService, account: account),
           let token = String(data: tokenData, encoding: .utf8) {
            accessToken = token
        }

        if let refreshData = KeychainHelper.standard.read(service: refreshTokenService, account: account),
           let token = String(data: refreshData, encoding: .utf8) {
            refreshToken = token
        }

        if let userData = KeychainHelper.standard.read(service: userService, account: account),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
        }
    }

    func saveSession(user: User, accessToken: String, refreshToken: String) {
        currentUser = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken

        if let tokenData = accessToken.data(using: .utf8) {
            KeychainHelper.standard.save(tokenData, service: accessTokenService, account: account)
        }

        if let refreshData = refreshToken.data(using: .utf8) {
            KeychainHelper.standard.save(refreshData, service: refreshTokenService, account: account)
        }

        if let userData = try? JSONEncoder().encode(user) {
            KeychainHelper.standard.save(userData, service: userService, account: account)
        }
    }

    func logout() {
        currentUser = nil
        accessToken = nil
        refreshToken = nil

        KeychainHelper.standard.delete(service: accessTokenService, account: account)
        KeychainHelper.standard.delete(service: refreshTokenService, account: account)
        KeychainHelper.standard.delete(service: userService, account: account)
    }
}

