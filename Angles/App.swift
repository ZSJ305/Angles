import SwiftUI

@main
struct AnglesApp: App {
    @State private var hasConfiguredProvider = UserDefaults.standard.bool(forKey: "hasConfiguredProvider")
    
    var body: some Scene {
        WindowGroup {
            if hasConfiguredProvider {
                ContentView()
            } else {
                WelcomeView(hasConfiguredProvider: $hasConfiguredProvider)
            }
        }
    }
}