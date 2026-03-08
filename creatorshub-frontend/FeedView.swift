import SwiftUI
import UIKit

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
                                FeedPostView(
                                    track: track,
                                    onToggleLike: { _ in toggleLike(trackId: track.trackId) }
                                )
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

    private func toggleLike(trackId: String) {
        guard let token = session.accessToken else {
            errorMessage = "Please log in to like tracks."
            return
        }

        guard let index = tracks.firstIndex(where: { $0.trackId == trackId }) else {
            return
        }

        let newValue = !tracks[index].likedByMe
        tracks[index].likedByMe = newValue
        tracks[index].likesCount += newValue ? 1 : -1
        tracks[index].likesCount = max(tracks[index].likesCount, 0)

        let service = newValue ? APIService.shared.likeTrack : APIService.shared.unlikeTrack

        service(trackId, token) { result in
            if case .failure(let error) = result {
                DispatchQueue.main.async {
                    guard let revertIndex = self.tracks.firstIndex(where: { $0.trackId == trackId }) else {
                        return
                    }
                    self.tracks[revertIndex].likedByMe.toggle()
                    self.tracks[revertIndex].likesCount += self.tracks[revertIndex].likedByMe ? 1 : -1
                    self.tracks[revertIndex].likesCount = max(self.tracks[revertIndex].likesCount, 0)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

extension Notification.Name {
    static let trackUploaded = Notification.Name("trackUploaded")
}

struct FeedPostView: View {
    let track: FeedTrack
    var onToggleLike: ((FeedTrack) -> Void)?
    var onMediaTapped: ((FeedTrack) -> Void)?
    @ObservedObject private var audio = FeedAudioManager.shared

    private var coverURL: URL? {
        absoluteURL(for: track.coverImageUrl)
    }

    private var audioURL: URL? {
        absoluteURL(for: track.fileUrl)
    }

    private var isActive: Bool {
        audio.activeTrackId == track.trackId
    }

    private var isMutedForActiveTrack: Bool {
        guard isActive else { return true }
        return audio.isMuted
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

            ZStack(alignment: .bottomLeading) {
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
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.6), .black.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 64))
                                .foregroundColor(.white.opacity(0.7))
                        )
                }

                HStack {
                    Label {
                        Text(isActive ? (audio.isPlaying ? "Playing" : "Paused") : "Preview")
                            .font(.caption)
                    } icon: {
                        Image(systemName: isActive && audio.isPlaying ? "waveform" : "play.circle")
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(.white)

                    Spacer()

                    Button {
                        audio.toggleMute(for: track.trackId, url: audioURL)
                    } label: {
                        Image(systemName: isMutedForActiveTrack ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.35))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isMutedForActiveTrack ? "Unmute preview" : "Mute preview")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .frame(height: 200)
            .clipped()
            .cornerRadius(16)
            .modifier(MediaTapModifier(isEnabled: onMediaTapped != nil) {
                onMediaTapped?(track)
            })
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            handleVisibility(frame: proxy.frame(in: .global))
                        }
                        .onChange(of: proxy.frame(in: .global)) { frame in
                            handleVisibility(frame: frame)
                        }
                        .onDisappear {
                            audio.trackLeftViewport(trackId: track.trackId)
                        }
                }
            )

            HStack(spacing: 24) {
                if let onToggleLike = onToggleLike {
                    Button {
                        onToggleLike(track)
                    } label: {
                        Label("\(track.likesCount)", systemImage: track.likedByMe ? "heart.fill" : "heart")
                            .foregroundColor(track.likedByMe ? .pink : .secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label("\(track.likesCount)", systemImage: track.likedByMe ? "heart.fill" : "heart")
                        .foregroundColor(track.likedByMe ? .pink : .secondary)
                }

                Label("\(track.commentsCount)", systemImage: "text.bubble")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    private func handleVisibility(frame: CGRect) {
        guard frame.height > 0 else { return }
        let screenHeight = UIScreen.main.bounds.height
        let upper = max(frame.minY, 0)
        let lower = min(frame.maxY, screenHeight)
        let visibleHeight = max(0, lower - upper)
        let ratio = max(0, min(visibleHeight / frame.height, 1))
        audio.updateVisibility(for: track.trackId, ratio: ratio, url: audioURL)
    }
}

private struct MediaTapModifier: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.simultaneousGesture(
                TapGesture().onEnded {
                    action()
                }
            )
        } else {
            content
        }
    }
}

struct TrackDetailView: View {
    @EnvironmentObject private var session: UserSession
    @State private var track: FeedTrack
    @ObservedObject private var audio = FeedAudioManager.shared
    @State private var comments: [Comment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingFullscreenPlayer = false

    init(track: FeedTrack) {
        _track = State(initialValue: track)
    }

    private var audioURL: URL? {
        absoluteURL(for: track.fileUrl)
    }

    var body: some View {
        List {
            Section {
                FeedPostView(
                    track: track,
                    onToggleLike: { _ in toggleLike() },
                    onMediaTapped: { _ in showingFullscreenPlayer = true }
                )
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
            audio.pin(trackId: track.trackId, url: audioURL)
            loadDetail()
        }
        .onDisappear {
            audio.unpin(trackId: track.trackId)
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showingFullscreenPlayer) {
            FullScreenAudioPlayerView(track: track, audioURL: audioURL)
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

struct FullScreenAudioPlayerView: View {
    let track: FeedTrack
    let audioURL: URL?
    @ObservedObject private var audio = FeedAudioManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sliderValue: Double = 0
    @State private var isEditingSlider = false

    private var coverURL: URL? {
        absoluteURL(for: track.coverImageUrl ?? track.fileUrl)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }

                    Spacer()
                    Text(track.user.displayName)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.footnote)
                }

                Spacer()

                if let coverURL = coverURL {
                    AsyncImage(url: coverURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .progressViewStyle(.circular)
                                .frame(height: 240)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 320)
                                .cornerRadius(24)
                        case .failure:
                            defaultArtwork
                        @unknown default:
                            defaultArtwork
                        }
                    }
                } else {
                    defaultArtwork
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(track.title)
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    if let caption = track.caption, !caption.isEmpty {
                        Text(caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { isEditingSlider ? sliderValue : audio.currentTime },
                            set: { newValue in
                                sliderValue = newValue
                            }
                        ),
                        in: 0...(audio.duration > 0 ? audio.duration : 1),
                        onEditingChanged: { editing in
                            isEditingSlider = editing
                            if !editing {
                                audio.seek(to: sliderValue)
                            }
                        }
                    )
                    .tint(.white)

                    HStack {
                        Text(formatTime(isEditingSlider ? sliderValue : audio.currentTime))
                        Spacer()
                        Text(formatTime(audio.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                }

                HStack(spacing: 24) {
                    Button {
                        audio.togglePlayPause(for: track.trackId, url: audioURL)
                    } label: {
                        Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }

                    Button {
                        audio.toggleMute(for: track.trackId, url: audioURL)
                    } label: {
                        Image(systemName: audio.isMuted ? "speaker.slash.circle.fill" : "speaker.wave.2.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            audio.pin(trackId: track.trackId, url: audioURL)
            sliderValue = audio.currentTime
        }
        .onChange(of: audio.currentTime) { newValue in
            if !isEditingSlider {
                sliderValue = newValue
            }
        }
    }

    private var defaultArtwork: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(
                LinearGradient(colors: [.purple, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(height: 280)
            .overlay(
                Image(systemName: "waveform.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.8))
            )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "--:--" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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

private func relativeDateString(from date: Date?) -> String {
    guard let date = date else { return "just now" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
