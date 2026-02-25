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
    @State private var pendingUserId: String?
    @State private var verificationEmail: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationStatus: String = ""
    @State private var isVerifyingCode = false
    @State private var showVerificationSheet = false

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
        .sheet(isPresented: $showVerificationSheet) {
            VerificationSheet(
                email: verificationEmail,
                code: $verificationCode,
                statusMessage: verificationStatus,
                isSubmitting: isVerifyingCode,
                onSubmit: verifyPendingAccount
            )
            .presentationDetents([.medium])
            .interactiveDismissDisabled(isVerifyingCode)
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
                        self.handleAuthError(error, fallbackMessage: "Login failed")
                    }
                }
            }
        case .register:
            APIService.shared.register(email: email, password: password, username: username, displayName: displayName) { result in
                DispatchQueue.main.async {
                    self.isLoading = false
                    switch result {
                    case .success(let response):
                        self.presentVerificationState(userId: response.userId, email: self.email)
                        self.statusMessage = "Verification required. Check \(self.email) for a code."
                    case .failure(let error):
                        self.handleAuthError(error, fallbackMessage: "Registration failed")
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

    private func handleAuthError(_ error: Error, fallbackMessage: String) {
        if let apiError = error as? APIErrorResponse {
            if apiError.error == "EMAIL_NOT_VERIFIED", let userId = apiError.userId {
                presentVerificationState(userId: userId, email: email)
                statusMessage = "Please verify your email to continue."
            } else {
                statusMessage = apiError.error
            }
        } else {
            statusMessage = "\(fallbackMessage): \(error.localizedDescription)"
        }
    }

    private func presentVerificationState(userId: String, email: String) {
        pendingUserId = userId
        verificationEmail = email
        verificationCode = ""
        verificationStatus = "Enter the 6-digit code sent to \(email)."
        showVerificationSheet = true
    }

    private func verifyPendingAccount() {
        guard let userId = pendingUserId else { return }
        guard verificationCode.count == 6 else {
            verificationStatus = "Enter the 6-digit code."
            return
        }

        isVerifyingCode = true
        verificationStatus = ""

        APIService.shared.verifyCode(userId: userId, code: verificationCode) { result in
            DispatchQueue.main.async {
                self.isVerifyingCode = false
                switch result {
                case .success(let auth):
                    self.session.saveSession(user: auth.user, accessToken: auth.accessToken, refreshToken: auth.refreshToken)
                    self.showVerificationSheet = false
                    self.pendingUserId = nil
                    self.verificationEmail = ""
                    self.verificationCode = ""
                    self.statusMessage = "Account verified. Welcome, \(auth.user.displayName)!"
                case .failure(let error):
                    if let apiError = error as? APIErrorResponse {
                        self.verificationStatus = apiError.error
                    } else {
                        self.verificationStatus = error.localizedDescription
                    }
                }
            }
        }
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

private struct VerificationSheet: View {
    let email: String
    @Binding var code: String
    let statusMessage: String
    let isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Verify \(email)")
                .font(.headline)

            Text("We just sent a 6-digit code to your inbox. Enter it below to activate your account.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .onChange(of: code) { newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    code = String(filtered.prefix(6))
                }

            Button {
                onSubmit()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                    }
                    Text("Verify Account")
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(code.count != 6 || isSubmitting)
            .padding()
            .background(code.count == 6 && !isSubmitting ? Color.accentColor : Color.gray.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(12)

            Text(statusMessage)
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}
