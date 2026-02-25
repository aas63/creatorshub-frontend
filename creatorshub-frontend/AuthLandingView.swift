import SwiftUI

enum AuthMode: String, CaseIterable {
    case login = "Login"
    case register = "Register"
}

struct AuthLandingView: View {
    @EnvironmentObject private var session: UserSession
    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var statusMessage = ""
    @State private var isLoading = false

    private let neonBlue = Color(red: 0.22, green: 0.64, blue: 0.98)
    private let deepPurple = Color(red: 0.15, green: 0.07, blue: 0.25)

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, deepPurple, Color.black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(neonBlue.opacity(0.25))
                .blur(radius: 90)
                .frame(width: 340, height: 340)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.purple.opacity(0.25))
                .blur(radius: 120)
                .frame(width: 360, height: 360)
                .offset(x: 140, y: 220)

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 6) {
                    Text("CREATORSHUB")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [neonBlue, .white], startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: neonBlue.opacity(0.8), radius: 12, y: 6)
                }

                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(spacing: 14) {
                    AuthInputField(
                        title: "Email",
                        placeholder: "napsterfan@signal.fm",
                        text: $email,
                        isSecure: false
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    AuthInputField(
                        title: "Password",
                        placeholder: "••••••••",
                        text: $password,
                        isSecure: true
                    )

                    if mode == .register {
                        AuthInputField(
                            title: "Username",
                            placeholder: "neonbyte",
                            text: $username,
                            isSecure: false
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        AuthInputField(
                            title: "Display Name",
                            placeholder: "Neon Byte",
                            text: $displayName,
                            isSecure: false
                        )
                    }
                }
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)

                Button(action: handleAuthAction) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: mode == .login ? "lock.open" : "sparkles")
                        }
                        Text(mode == .login ? "Log In" : "Create Account")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(neonBlue)
                    .foregroundColor(.black)
                    .cornerRadius(18)
                    .shadow(color: neonBlue.opacity(0.6), radius: 22, y: 8)
                }
                .disabled(isLoading)

                Text(statusMessage)
                    .font(.footnote.monospaced())
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }

    private func handleAuthAction() {
        statusMessage = ""
        guard validateInputs() else { return }

        isLoading = true

        switch mode {
        case .login:
            APIService.shared.login(email: email, password: password) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success(let auth):
                        self.session.saveSession(user: auth.user, accessToken: auth.accessToken, refreshToken: auth.refreshToken)
                        self.statusMessage = "Welcome back, \(auth.user.username)!"
                    case .failure(let error):
                        self.statusMessage = "Login failed: \(error.localizedDescription)"
                    }
                }
            }
        case .register:
            APIService.shared.register(email: email, password: password, username: username, displayName: displayName) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success(let auth):
                        self.session.saveSession(user: auth.user, accessToken: auth.accessToken, refreshToken: auth.refreshToken)
                        self.statusMessage = "Welcome, \(auth.user.displayName)!"
                    case .failure(let error):
                        self.statusMessage = "Registration failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func validateInputs() -> Bool {
        if email.isEmpty || password.isEmpty {
            statusMessage = "Email and password are required."
            return false
        }

        if mode == .register {
            if username.isEmpty || displayName.isEmpty {
                statusMessage = "Username and display name are required."
                return false
            }
        }

        return true
    }
}

struct AuthLandingView_Previews: PreviewProvider {
    static var previews: some View {
        AuthLandingView()
            .environmentObject(UserSession.shared)
    }
}

// MARK: - Components

private struct AuthInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color.black.opacity(0.35))
                    )
                    .frame(height: 48)

                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 12)
                }

                Group {
                    if isSecure {
                        SecureField("", text: $text)
                    } else {
                        TextField("", text: $text)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .frame(height: 48)
            }
        }
    }
}
