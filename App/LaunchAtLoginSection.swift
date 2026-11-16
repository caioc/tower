import AppKit
import Core
import SwiftUI

struct LaunchAtLoginSection: View {
  @State private var model = LaunchAtLoginModel()
  @AppStorage(PanelSettingsKeys.layout) private var panelLayout = PanelLayout.split

  var body: some View {
    Section("General") {
      Toggle("Launch at login", isOn: $model.isOn)
      if let caption = model.caption {
        Text(caption)
          .font(.caption)
          .foregroundStyle(Theme.textSecondary)
      }
      Picker("Panel view", selection: $panelLayout) {
        ForEach(PanelLayout.allCases, id: \.self) { layout in
          Text(layout.title).tag(layout)
        }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      model.refresh()
    }
  }
}
