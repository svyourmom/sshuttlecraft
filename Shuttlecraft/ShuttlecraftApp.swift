import SwiftUI

@main
struct ShuttlecraftApp: App {
    // This line tells SwiftUI to use our AppDelegate class
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // By having only a Settings scene (or no scene that creates a window if Settings is empty),
        // the app won't open a main window by default.
        // We'll manage everything from the AppDelegate.
        Settings {
            // We can add settings UI here later if needed.
            // For now, leaving it empty means no window will appear from here.
        }
    }
}
