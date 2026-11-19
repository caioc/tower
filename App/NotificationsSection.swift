import AppKit
import Core
import SwiftUI
import UserNotifications

struct NotificationsSection: View {
  @State private var isDenied = false

  var body: some View {
    SettingsRow(label: "Notifications") {
      ForEach(NotificationEventKind.allCases, id: \.self) { kind in
        NotificationKindToggle(kind: kind) {
          // Launch asks only when a switch is on, so a switch turned on later asks here. macOS prompts at most once.
          guard !DemoLaunch.isActive else { return }
          Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            await refreshAuthorization()
          }
        }
      }
      if isDenied {
        SettingsCaption(text: "macOS blocks Tower notifications.")
        Button("Open System Settings") {
          let bundleId = Bundle.main.bundleIdentifier ?? ""
          NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleId)")!)
        }
      }
    }
    .task { await refreshAuthorization() }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      Task { await refreshAuthorization() }
    }
  }

  private func refreshAuthorization() async {
    isDenied = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
  }
}

private struct NotificationKindToggle: View {
  let kind: NotificationEventKind
  let turnedOn: () -> Void
  @AppStorage private var isOn: Bool

  init(kind: NotificationEventKind, turnedOn: @escaping () -> Void) {
    self.kind = kind
    self.turnedOn = turnedOn
    _isOn = AppStorage(wrappedValue: true, NotificationSettingsKeys.key(kind))
  }

  var body: some View {
    Toggle(kind.title, isOn: $isOn)
      .toggleStyle(.checkbox)
      .onChange(of: isOn) { _, isOn in
        if isOn { turnedOn() }
      }
  }
}
