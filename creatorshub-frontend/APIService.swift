import Foundation

struct User: Codable {
    let id: String
    let username: String
    let displayName: String
    let bio: String?
    let profileImageUrl: String?
}

struct AuthResponse: Codable {
    let user: User
    let accessToken: String
    let refreshToken: String
}

struct RegistrationResponse: Codable {
    let userId: String
    let message: String
    let expiresAt: String?
}

struct APIErrorResponse: Codable, LocalizedError {
    let error: String
    let userId: String?

    var errorDescription: String? { error }
}

struct Track: Codable {
    let trackId: String
    let userId: String
    let title: String
    let description: String?
    let fileUrl: String
    let coverImageUrl: String?
}

class APIService {
    static let shared = APIService()
    private let baseURL = "http://localhost:3000"

    private init() {}

    // MARK: - Register
    func register(email: String, password: String, username: String, displayName: String, completion: @escaping (Result<RegistrationResponse, Error>) -> Void) {

        guard let url = URL(string: "\(baseURL)/auth/register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password,
            "username": username,
            "displayName": displayName
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let data = data,
                let httpResponse = response as? HTTPURLResponse
            else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let response = try JSONDecoder().decode(RegistrationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Login
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/login") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let data = data,
                let httpResponse = response as? HTTPURLResponse
            else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                completion(.success(authResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Current User
    func getCurrentUser(accessToken: String, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/me") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let data = data,
                let httpResponse = response as? HTTPURLResponse
            else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let user = try JSONDecoder().decode(User.self, from: data)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Upload Track
    func uploadTrack(
        fileURL: URL,
        title: String,
        description: String,
        coverImageData: Data?,
        accessToken: String,
        completion: @escaping (Result<Track, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)/tracks/upload") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendTextField(data: &body, name: "title", value: title, boundary: boundary)
        appendTextField(data: &body, name: "description", value: description, boundary: boundary)

        guard let fileData = try? Data(contentsOf: fileURL) else {
            completion(.failure(NSError(domain: "FileRead", code: -1)))
            return
        }

        appendFileField(
            data: &body,
            name: "file",
            filename: fileURL.lastPathComponent,
            mimeType: mimeType(for: fileURL),
            fileData: fileData,
            boundary: boundary
        )

        if let coverData = coverImageData {
            appendFileField(
                data: &body,
                name: "coverImage",
                filename: "cover.jpg",
                mimeType: "image/jpeg",
                fileData: coverData,
                boundary: boundary
            )
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { responseData, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let responseData = responseData,
                let httpResponse = response as? HTTPURLResponse
            else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: responseData) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let track = try JSONDecoder().decode(Track.self, from: responseData)
                completion(.success(track))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func verifyCode(userId: String, code: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/verify") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "userId": userId,
            "code": code
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard
                let data = data,
                let httpResponse = response as? HTTPURLResponse
            else {
                completion(.failure(NSError(domain: "NoData", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
                completion(.success(auth))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func appendTextField(data: inout Data, name: String, value: String, boundary: String) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        data.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func appendFileField(
        data: inout Data,
        name: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        boundary: String
    ) {
        data.append("--\(boundary)\r\n".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        data.append(fileData)
        data.append("\r\n".data(using: .utf8)!)
    }

    private func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "m4a":
            return "audio/m4a"
        case "aac":
            return "audio/aac"
        default:
            return "application/octet-stream"
        }
    }
}
