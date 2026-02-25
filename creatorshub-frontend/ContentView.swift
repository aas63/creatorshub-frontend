import SwiftUI

struct ContentView: View {
    @StateObject private var session = UserSession.shared

    var body: some View {
        Group {
            if session.accessToken != nil {
                MainTabView()
                    .environmentObject(session)
            } else {
                AuthLandingView()
                    .environmentObject(session)
            }
        }
        .animation(.easeInOut, value: session.accessToken != nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UserSession.shared)
    }
}
