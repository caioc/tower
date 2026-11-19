import AppKit
import Core
import Foundation
import UserNotifications

@MainActor protocol Notifier: AnyObject {
  func post(_ event: NotificationEvent)
  func requestAuthorization()
}

enum NotificationSettingsKeys {
  static func key(_ kind: NotificationEventKind) -> String { "notify.\(kind.rawValue)" }

  // A switch the owner never touched has no value, and it counts as on.
  static func enabledKinds(defaults: UserDefaults = .standard) -> Set<NotificationEventKind> {
    Set(NotificationEventKind.allCases.filter { defaults.object(forKey: key($0)) as? Bool ?? true })
  }
}

// Posts through the macOS notification center. A click opens the event URL in the browser.
final class UserNotificationNotifier: NSObject, Notifier, UNUserNotificationCenterDelegate {
  private nonisolated static let urlKey = "url"
  private let center: UNUserNotificationCenter

  init(center: UNUserNotificationCenter = .current()) {
    self.center = center
    super.init()
    center.delegate = self
  }

  func post(_ event: NotificationEvent) {
    center.add(Self.request(for: event))
  }

  func requestAuthorization() {
    center.requestAuthorization(options: [.alert]) { _, _ in }
  }

  // The event id is the request identifier, so a repeat replaces the old notification.
  nonisolated static func request(for event: NotificationEvent) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = event.title
    content.body = event.body
    content.userInfo = [urlKey: event.url.absoluteString]
    return UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
  }

  nonisolated static func url(fromUserInfo userInfo: [AnyHashable: Any]) -> URL? {
    (userInfo[urlKey] as? String).flatMap(URL.init(string:))
  }

  // Tower is the active app while the panel or Settings is open. Without this, macOS drops the banner then.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list]
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    guard let url = Self.url(fromUserInfo: response.notification.request.content.userInfo) else { return }
    await MainActor.run { _ = NSWorkspace.shared.open(url) }
  }
}
