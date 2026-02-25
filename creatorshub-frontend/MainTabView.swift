import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: UserSession

    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
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
