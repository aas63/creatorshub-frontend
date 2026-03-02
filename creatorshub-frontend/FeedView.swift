import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var session: UserSession
    @State private var tracks: [FeedTrack] = []
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && tracks.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if tracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text(errorMessage ?? "No uploads yet. Be the first to share a track.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(tracks) { track in
                            NavigationLink {
                                TrackDetailView(track: track)
                            } label: {
                                FeedPostView(track: track)
                                    .padding(.vertical, 8)
                            }
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshFeed()
                    }
                }
            }
            .navigationTitle("Feed")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                hasLoaded = true
                loadFeed()
            }
            .onReceive(NotificationCenter.default.publisher(for: .trackUploaded)) { _ in
                loadFeed(showSpinner: false)
            }
        }
    }

    private func loadFeed(showSpinner: Bool = true, completion: (() -> Void)? = nil) {
        guard let token = session.accessToken else { return }
        if showSpinner {
            isLoading = true
        }
        APIService.shared.fetchFeed(accessToken: token) { result in
            DispatchQueue.main.async {
                if showSpinner {
                    self.isLoading = false
                }
                switch result {
                case .success(let tracks):
                    self.tracks = tracks
                    self.errorMessage = tracks.isEmpty ? "No uploads yet. Be the first to share a track." : nil
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
                completion?()
            }
        }
    }

    private func refreshFeed() async {
        await withCheckedContinuation { continuation in
            loadFeed(showSpinner: false) {
                continuation.resume()
            }
        }
    }
}

extension Notification.Name {
    static let trackUploaded = Notification.Name("trackUploaded")
}

struct FeedPostView: View {
    let track: FeedTrack

    private var coverURL: URL? {
        absoluteURL(for: track.coverImageUrl)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(initials(for: track.user.displayName))
                            .font(.headline)
                            .foregroundColor(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(track.user.displayName)
                            .font(.headline)
                        Text("@\(track.user.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(relativeDateString(from: track.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let caption = track.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.body)
                    }
                }
            }

            if let coverURL = coverURL {
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(16)
            }

            HStack(spacing: 24) {
                Label("\(track.likesCount)", systemImage: "heart")
                Label("\(track.commentsCount)", systemImage: "text.bubble")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }
}

struct TrackDetailView: View {
    @EnvironmentObject private var session: UserSession
    @State private var track: FeedTrack
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    init(track: FeedTrack) {
        _track = State(initialValue: track)
    }

    var body: some View {
        List {
            Section {
                FeedPostView(track: track)
                    .padding(.vertical, 8)

                HStack(spacing: 24) {
                    Button {
                        toggleLike()
                    } label: {
                        Label(
                            track.likedByMe ? "Liked" : "Like",
                            systemImage: track.likedByMe ? "heart.fill" : "heart"
                        )
                    }
                    .tint(track.likedByMe ? .pink : .primary)

                    Label("\(track.commentsCount) Comments", systemImage: "text.bubble")
                        .foregroundColor(.secondary)
                }
            }

            Section("Comments") {
                if comments.isEmpty {
                    Text(isLoading ? "Loading comments..." : "No comments yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(comments) { comment in
                        CommentRow(comment: comment)
                    }
                }
            }

            Section("Add a comment") {
                VStack(spacing: 8) {
                    TextField("Say something...", text: $newComment, axis: .vertical)
                    Button("Post Comment") {
                        postComment()
                    }
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isLoading {
                ProgressView()
            }
        }
        .onAppear {
            loadDetail()
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadDetail() {
        guard let token = session.accessToken else { return }
        isLoading = true
        APIService.shared.fetchTrackDetail(trackId: track.trackId, accessToken: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let detail):
                    self.track = detail.track
                    self.comments = detail.comments
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func toggleLike() {
        guard let token = session.accessToken else { return }
        let isLiked = track.likedByMe
        let service = isLiked ? APIService.shared.unlikeTrack : APIService.shared.likeTrack

        service(track.trackId, token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    track.likedByMe.toggle()
                    track.likesCount += track.likedByMe ? 1 : -1
                    track.likesCount = max(track.likesCount, 0)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func postComment() {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let token = session.accessToken else { return }

        APIService.shared.addComment(trackId: track.trackId, text: trimmed, accessToken: token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let comment):
                    newComment = ""
                    comments.insert(comment, at: 0)
                    track.commentsCount += 1
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.user.displayName)
                    .font(.subheadline).bold()
                Text("@\(comment.user.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(relativeDateString(from: comment.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(comment.text)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}

private func absoluteURL(for path: String?) -> URL? {
    guard let path = path, !path.isEmpty else { return nil }
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
        return URL(string: path)
    }
    let cleaned = path.hasPrefix("/") ? path : "/\(path)"
    return URL(string: APIService.shared.baseURL + cleaned)
}

private func relativeDateString(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
