import AppKit
import SwiftUI

struct LaunchAtLoginSection: View {
  @State private var model = LaunchAtLoginModel()

  var body: some View {
    SettingsRow(label: "Login") {
      Toggle("Launch at login", isOn: $model.isOn)
        .toggleStyle(.checkbox)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
          model.refresh()
        }
      SettingsCaption(text: model.caption)
      SettingsCaption(
        text: "Starts Tower when you log in. You can also change this in System Settings > General > Login Items.")
    }
  }
}
