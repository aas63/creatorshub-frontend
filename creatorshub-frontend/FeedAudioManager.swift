import Foundation
import AVFoundation
import CoreGraphics

@MainActor
final class FeedAudioManager: ObservableObject {
    static let shared = FeedAudioManager()

    @Published private(set) var activeTrackId: String?
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isMuted: Bool = true
    @Published private(set) var pinnedTrackId: String?

    private var player: AVPlayer?
    private var endObserver: Any?
    private var visibility: [String: CGFloat] = [:]
    private var currentURL: URL?
    private let autoplayThreshold: CGFloat = 0.6
    private let pauseThreshold: CGFloat = 0.1
    private var audioSessionConfigured = false

    private init() {}

    func updateVisibility(for trackId: String, ratio: CGFloat, url: URL?) {
        visibility[trackId] = ratio

        guard pinnedTrackId == nil else { return }

        if ratio >= autoplayThreshold {
            guard let url = url else { return }
            if activeTrackId != trackId {
                startPlayback(with: url, trackId: trackId, muted: true)
            } else if player?.timeControlStatus != .playing {
                player?.play()
                isPlaying = true
            }
        } else if ratio < pauseThreshold {
            if activeTrackId == trackId {
                pauseCurrentTrack(clearActive: true)
            }
        }
    }

    func trackLeftViewport(trackId: String) {
        visibility.removeValue(forKey: trackId)
        if pinnedTrackId == trackId {
            return
        }
        if activeTrackId == trackId {
            pauseCurrentTrack(clearActive: true)
        }
    }

    func unmute(trackId: String, url: URL?) {
        ensurePlayback(for: trackId, url: url, muted: false)
    }

    func toggleMute(for trackId: String, url: URL?) {
        ensurePlayback(for: trackId, url: url)
        let newValue = !isMuted
        player?.isMuted = newValue
        isMuted = newValue
    }

    func togglePlayPause(for trackId: String, url: URL?) {
        guard activeTrackId == trackId else {
            ensurePlayback(for: trackId, url: url, muted: isMuted)
            return
        }

        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }

    func pin(trackId: String, url: URL?) {
        pinnedTrackId = trackId
        ensurePlayback(for: trackId, url: url)
    }

    func unpin(trackId: String) {
        guard pinnedTrackId == trackId else { return }
        pinnedTrackId = nil
        guard let ratio = visibility[trackId], ratio >= autoplayThreshold else {
            // No longer visible; stop playback so another post can autoplay.
            pauseCurrentTrack(clearActive: true)
            return
        }
        // Still visible; allow autoplay loop to continue without interference.
    }

    private func ensurePlayback(for trackId: String, url: URL?, muted: Bool? = nil) {
        let shouldMute = muted ?? isMuted

        if activeTrackId == trackId {
            if let mutedValue = muted {
                player?.isMuted = mutedValue
                isMuted = mutedValue
            }
            if player?.timeControlStatus != .playing {
                player?.play()
                isPlaying = true
            }
            return
        }

        guard let resolvedURL = url ?? currentURL else { return }
        startPlayback(with: resolvedURL, trackId: trackId, muted: shouldMute)
    }

    private func startPlayback(with url: URL, trackId: String, muted: Bool) {
        configureAudioSessionIfNeeded()

        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.isMuted = muted
        player.play()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isPlaying = false
        }

        self.player = player
        currentURL = url
        activeTrackId = trackId
        isMuted = muted
        isPlaying = true
    }

    private func pauseCurrentTrack(clearActive: Bool) {
        player?.pause()
        isPlaying = false
        if clearActive {
            player = nil
            currentURL = nil
            activeTrackId = nil
        }
    }

    private func configureAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true, options: [])
            audioSessionConfigured = true
        } catch {
            print("[FeedAudioManager] Failed to configure audio session:", error)
        }
    }
}
