import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: UserSession

    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Feed")
                }

            UploadTrackView()
                .tabItem {
                    Image(systemName: "music.note")
                    Text("Upload")
                }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(UserSession.shared)
    }
}
