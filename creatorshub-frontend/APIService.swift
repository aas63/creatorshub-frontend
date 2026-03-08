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

struct TrackUserReference: Codable {
    let id: String
    let username: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName
    }

    init(id: String, username: String, displayName: String) {
        self.id = id
        self.username = username
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let username = try container.decode(String.self, forKey: .username)
        let displayName = (try? container.decode(String.self, forKey: .displayName))?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.id = id
        self.username = username
        self.displayName = (displayName?.isEmpty == false ? displayName! : username)
    }
}

struct FeedTrack: Codable, Identifiable {
    let trackId: String
    var id: String { trackId }
    let userId: String
    let title: String
    let description: String?
    let caption: String?
    let fileUrl: String
    let coverImageUrl: String?
    let createdAt: Date?
    var likesCount: Int
    var commentsCount: Int
    var likedByMe: Bool
    let user: TrackUserReference

    enum CodingKeys: String, CodingKey {
        case trackId
        case userId
        case title
        case description
        case caption
        case fileUrl
        case coverImageUrl
        case createdAt
        case likesCount
        case commentsCount
        case likedByMe
        case user
    }

    init(
        trackId: String,
        userId: String,
        title: String,
        description: String?,
        caption: String?,
        fileUrl: String,
        coverImageUrl: String?,
        createdAt: Date?,
        likesCount: Int,
        commentsCount: Int,
        likedByMe: Bool,
        user: TrackUserReference
    ) {
        self.trackId = trackId
        self.userId = userId
        self.title = title
        self.description = description
        self.caption = caption
        self.fileUrl = fileUrl
        self.coverImageUrl = coverImageUrl
        self.createdAt = createdAt
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.likedByMe = likedByMe
        self.user = user
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackId = try container.decode(String.self, forKey: .trackId)
        userId = try container.decode(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        description = try? container.decode(String.self, forKey: .description)
        caption = try? container.decode(String.self, forKey: .caption)
        fileUrl = try container.decode(String.self, forKey: .fileUrl)
        coverImageUrl = try? container.decode(String.self, forKey: .coverImageUrl)
        createdAt = try? container.decode(Date.self, forKey: .createdAt)
        likesCount = container.decodeFlexibleInt(forKey: .likesCount)
        commentsCount = container.decodeFlexibleInt(forKey: .commentsCount)
        likedByMe = container.decodeFlexibleBool(forKey: .likedByMe)
        user = try container.decode(TrackUserReference.self, forKey: .user)
    }
}

struct TrackUploadResponse: Codable {
    let trackId: String
    let userId: String
    let title: String
    let description: String?
    let caption: String?
    let fileUrl: String
    let coverImageUrl: String?
    let createdAt: Date?
}

struct Comment: Codable, Identifiable {
    let id: String
    let trackId: String
    let text: String
    let createdAt: Date
    let user: TrackUserReference
}

struct TrackDetailResponse: Codable {
    let track: FeedTrack
    let comments: [Comment]
}

class APIService {
    static let shared = APIService()
    let baseURL = "http://localhost:3000"

    private init() {}

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Register
    func register(email: String, password: String, username: String, displayName: String, completion: @escaping (Result<RegistrationResponse, Error>) -> Void) {
        let decoder = makeDecoder()

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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let response = try decoder.decode(RegistrationResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    // MARK: - Login
    func login(email: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let decoder = makeDecoder()
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                completion(.success(authResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Current User
    func getCurrentUser(accessToken: String, completion: @escaping (Result<User, Error>) -> Void) {
        let decoder = makeDecoder()
        guard let url = URL(string: "\(baseURL)/users/me") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [self] data, response, error in
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let user = try decoder.decode(User.self, from: data)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Upload Track
    func uploadTrack(
        fileURL: URL,
        title trackTitle: String,
        description trackDescription: String,
        caption trackCaption: String,
        coverImageData: Data?,
        accessToken: String,
        completion: @escaping (Result<TrackUploadResponse, Error>) -> Void
    ) {
        let decoder = makeDecoder()
        guard let url = URL(string: "\(baseURL)/tracks/upload") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        appendTextField(data: &body, name: "title", value: trackTitle, boundary: boundary)
        appendTextField(data: &body, name: "description", value: trackDescription, boundary: boundary)
        appendTextField(data: &body, name: "caption", value: trackCaption, boundary: boundary)

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

        URLSession.shared.uploadTask(with: request, from: body) { [self] responseData, response, error in
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: responseData) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let track = try decoder.decode(TrackUploadResponse.self, from: responseData)
                completion(.success(track))
            } catch {
                if let fallback = parseUploadResponseFallback(data: responseData, title: trackTitle, caption: trackCaption) {
                    completion(.success(fallback))
                } else {
                    #if DEBUG
                    if let raw = String(data: responseData, encoding: .utf8) {
                        print("Upload decode error:", raw)
                    }
                    #endif
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func verifyCode(userId: String, code: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        let decoder = makeDecoder()
        guard let url = URL(string: "\(baseURL)/auth/verify") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "userId": userId,
            "code": code
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        URLSession.shared.dataTask(with: request) { [self] data, response, error in
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let auth = try decoder.decode(AuthResponse.self, from: data)
                completion(.success(auth))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Feed
    func fetchFeed(accessToken: String, completion: @escaping (Result<[FeedTrack], Error>) -> Void) {
        let decoder = makeDecoder()
        guard let url = URL(string: "\(baseURL)/tracks") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let tracks = try decoder.decode([FeedTrack].self, from: data)
                completion(.success(tracks))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func fetchTrackDetail(trackId: String, accessToken: String, completion: @escaping (Result<TrackDetailResponse, Error>) -> Void) {
        let decoder = makeDecoder()
        guard let url = URL(string: "\(baseURL)/tracks/\(trackId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let detail = try decoder.decode(TrackDetailResponse.self, from: data)
                completion(.success(detail))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func likeTrack(trackId: String, accessToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/tracks/\(trackId)/like") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NoResponse", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                return
            }

            completion(.success(()))
        }.resume()
    }

    func unlikeTrack(trackId: String, accessToken: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/tracks/\(trackId)/like") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "NoResponse", code: -1)))
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                return
            }

            completion(.success(()))
        }.resume()
    }

    func addComment(trackId: String, text: String, accessToken: String, completion: @escaping (Result<Comment, Error>) -> Void) {
        let decoder = makeDecoder()
        guard let url = URL(string: "\(baseURL)/tracks/\(trackId)/comments") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let payload = ["text": text]
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
                if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                    completion(.failure(apiError))
                } else {
                    completion(.failure(NSError(domain: "ServerError", code: httpResponse.statusCode)))
                }
                return
            }

            do {
                let comment = try decoder.decode(Comment.self, from: data)
                completion(.success(comment))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func parseUploadResponseFallback(data: Data, title: String, caption: String) -> TrackUploadResponse? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return nil
        }

        let trackId = object["trackId"] as? String ?? UUID().uuidString
        let userId = object["userId"] as? String ?? ""
        let description = object["description"] as? String
        let captionValue = object["caption"] as? String ?? caption
        let fileUrl = object["fileUrl"] as? String ?? ""
        let coverImageUrl = object["coverImageUrl"] as? String
        let createdAtString = object["createdAt"] as? String
        let createdAtDate = createdAtString.flatMap { ISO8601DateFormatter().date(from: $0) }

        return TrackUploadResponse(
            trackId: trackId,
            userId: userId,
            title: object["title"] as? String ?? title,
            description: description,
            caption: captionValue,
            fileUrl: fileUrl,
            coverImageUrl: coverImageUrl,
            createdAt: createdAtDate
        )
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

private extension KeyedDecodingContainer where Key: CodingKey {
    func decodeFlexibleInt(forKey key: Key) -> Int {
        if let value = try? decode(Int.self, forKey: key) {
            return value
        }
        if let stringValue = try? decode(String.self, forKey: key), let intValue = Int(stringValue) {
            return intValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        if let boolValue = try? decode(Bool.self, forKey: key) {
            return boolValue ? 1 : 0
        }
        return 0
    }

    func decodeFlexibleBool(forKey key: Key) -> Bool {
        if let value = try? decode(Bool.self, forKey: key) {
            return value
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue != 0
        }
        if let stringValue = try? decode(String.self, forKey: key) {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "t", "1", "yes", "y"].contains(normalized) {
                return true
            }
            if ["false", "f", "0", "no", "n"].contains(normalized) {
                return false
            }
        }
        return false
    }
}
