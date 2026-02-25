import SwiftUI

struct HomeFeedView: View {
    @EnvironmentObject private var session: UserSession

    private let mockFeed: [TrackPreview] = [
        TrackPreview(artist: "NeonPulse", title: "Quantum Drift", coverEmoji: "🌀"),
        TrackPreview(artist: "AeroBloom", title: "Skyline Bloom", coverEmoji: "🌆"),
        TrackPreview(artist: "Velvet Array", title: "Ghost in Echo", coverEmoji: "👾"),
        TrackPreview(artist: "NovaPort", title: "Midnight Circuits", coverEmoji: "🌌")
    ]

    var body: some View {
        NavigationStack {
            List(mockFeed) { track in
                HStack(spacing: 16) {
                    Text(track.coverEmoji)
                        .font(.system(size: 30))
                        .frame(width: 52, height: 52)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.headline)
                        Text(track.artist)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                    Image(systemName: "waveform")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.logout()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Log out")
                }
            }
        }
    }
}

private struct TrackPreview: Identifiable {
    let id = UUID()
    let artist: String
    let title: String
    let coverEmoji: String
}

struct HomeFeedView_Previews: PreviewProvider {
    static var previews: some View {
        HomeFeedView()
            .environmentObject(UserSession.shared)
    }
}
