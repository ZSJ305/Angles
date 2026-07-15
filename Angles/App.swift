import SwiftUI
import SwiftData

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
        .modelContainer(for: [ChatMessage.self, ProviderConfig.self])
    }
}

/// Scene delegate for multi-window support on iPad
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {}
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}