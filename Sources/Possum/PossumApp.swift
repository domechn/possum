import SwiftUI

@main
struct PossumApp: App {
    @StateObject private var session = SessionController()

    var body: some Scene {
        Window("Possum", id: "main") {
            ContentView()
                .environmentObject(session)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 380, height: 340)
    }
}
