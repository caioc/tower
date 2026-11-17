import Core
import Foundation
import Security

enum SettingsStatusKind: Equatable {
  case connected
  case notSetUp
  case failed
  case checking
}

struct SettingsStatusRow: Equatable {
  let kind: SettingsStatusKind
  let text: String
}

// A test in progress shows Checking. A finished test result replaces the store status until the store status changes.
func settingsStatusRow(
  source: String, status: SourceStatus, testStatus: SourceStatus?, isTesting: Bool, connectedText: String
) -> SettingsStatusRow {
  let shownStatus = isTesting ? SourceStatus.idle : (testStatus ?? status)
  return switch shownStatus {
  case .idle: SettingsStatusRow(kind: .checking, text: "Checking…")
  case .ok: SettingsStatusRow(kind: .connected, text: connectedText)
  case .failed(.notConfigured): SettingsStatusRow(kind: .notSetUp, text: settingsFailureText(.notConfigured, source: source))
  case .failed(let failure): SettingsStatusRow(kind: .failed, text: settingsFailureText(failure, source: source))
  }
}

func settingsGitHubStatusText(status: SourceStatus, viewerLogin: String?) -> String {
  switch status {
  case .idle: "Checking…"
  case .ok: "Signed in as \(viewerLogin ?? "unknown") via gh"
  case .failed(let failure): settingsFailureText(failure, source: "GitHub")
  }
}

func settingsFailureText(_ failure: SourceFailure, source: String) -> String {
  switch failure {
  case .authentication:
    switch source {
    case "GitHub": "Not signed in. Run gh auth login."
    case "CircleCI": "Token rejected. Check the API token."
    default: "Sign-in failed. Check email and token."
    }
  case .network: "Can’t reach \(source)"
  case .notConfigured: "Not set up"
  case .unexpected(let message): message
  }
}

func circleciConnectedText(projectCount: Int) -> String {
  "Connected · \(projectCount) \(projectCount == 1 ? "project" : "projects")"
}

// An empty token deletes the Keychain item, so clearing the field signs the source out.
// Returns the text to show when the Keychain write fails, or nil.
func saveTrimmedToken(
  _ token: String, account: String,
  write: (String, String) throws -> Void = KeychainStore.write(_:account:),
  delete: (String) -> Void = KeychainStore.delete(account:)
) -> String? {
  let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
  if trimmedToken.isEmpty {
    delete(account)
    return nil
  }
  do {
    try write(trimmedToken, account)
    return nil
  } catch let keychainError as KeychainError {
    let reason = SecCopyErrorMessageString(keychainError.status, nil) as String? ?? "OSStatus \(keychainError.status)"
    return "Can’t save the token: \(reason)"
  } catch {
    return "Can’t save the token: \(error.localizedDescription)"
  }
}

// Mirrors the site check in JiraSettingsKeys.load, and also asks for https so the token never goes out in cleartext.
func jiraSiteURLHint(_ siteURL: String) -> String? {
  guard !siteURL.isEmpty else { return nil }
  if let site = URL(string: siteURL), site.scheme?.lowercased() == "https", site.host() != nil { return nil }
  return "Use the full URL, for example https://acme.atlassian.net"
}
