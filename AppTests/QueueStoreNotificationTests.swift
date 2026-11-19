import Core
import Foundation
import Testing

@testable import Tower

@MainActor private final class FakeNotifier: Notifier {
  var postedEvents: [NotificationEvent] = []
  func post(_ event: NotificationEvent) { postedEvents.append(event) }
  func requestAuthorization() {}
}

private struct StubTokenProvider: GitHubTokenProvider {
  func token() async throws(SourceFailure) -> String { "gh-token" }
}

// The test changes the values only between refreshes, so no lock is needed.
private final class CircleCIResponse: @unchecked Sendable {
  var workflowStatus = "running"
  var statusCode = 200
}

private let pipelineCreatedAt = Date().formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))

// One branch pipeline without a PR. Its state comes from the one workflow the stub returns.
private func circleciTransport(_ response: CircleCIResponse) throws -> StubTransport {
  let githubData = try fixture("github-search.json")
  return StubTransport { request in
    guard request.url?.host() == "circleci.com" else { return (githubData, 200) }
    let body =
      request.url!.path().hasSuffix("/workflow")
      ? #"{"items":[{"id":"workflow-1","name":"build","status":"\#(response.workflowStatus)","created_at":"\#(pipelineCreatedAt)"}]}"#
      : #"{"items":[{"id":"pipeline-1","number":7,"state":"created","created_at":"\#(pipelineCreatedAt)","project_slug":"gh/acme/app-web","trigger":{"type":"webhook"},"vcs":{"branch":"main"}}]}"#
    return (Data(body.utf8), response.statusCode)
  }
}

@MainActor private func makeStore(
  transport: StubTransport, notifier: FakeNotifier, cacheDirectory: URL? = nil,
  enabledKinds: Set<NotificationEventKind> = Set(NotificationEventKind.allCases)
) -> QueueStore {
  QueueStore(
    tokenProvider: StubTokenProvider(), transport: transport,
    cacheDirectory: cacheDirectory
      ?? FileManager.default.temporaryDirectory.appendingPathComponent("tower-notify-\(UUID().uuidString)"),
    loadJiraSettings: { nil },
    loadCircleCISettings: { CircleCISettings(apiToken: "circle-token", projectSlugs: ["gh/acme/app-web"]) },
    loadGitHubOrganizations: { [] }, notifier: notifier, loadEnabledNotificationKinds: { enabledKinds },
    defaults: UserDefaults(suiteName: "tower-notify-\(UUID().uuidString)")!)
}

@MainActor struct QueueStoreNotificationTests {
  @Test func firstRefreshPostsNothing() async throws {
    let response = CircleCIResponse()
    response.workflowStatus = "failed"
    let notifier = FakeNotifier()
    let store = makeStore(transport: try circleciTransport(response), notifier: notifier)
    await store.refresh()
    #expect(store.pipelines?.first?.state == .failed)
    #expect(notifier.postedEvents.isEmpty)
  }

  @Test func secondRefreshWithAChangePostsTheEvent() async throws {
    let response = CircleCIResponse()
    let notifier = FakeNotifier()
    let store = makeStore(transport: try circleciTransport(response), notifier: notifier)
    await store.refresh()
    response.workflowStatus = "failed"
    await store.refresh()
    #expect(notifier.postedEvents.map(\.kind) == [.ciFailed])
    #expect(notifier.postedEvents.first?.body == "main\napp-web #7")
    await store.refresh()
    #expect(notifier.postedEvents.count == 1)
  }

  @Test func cachedDataIsNotTheBaseline() async throws {
    let cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("tower-notify-\(UUID().uuidString)")
    let runningPipeline = Pipeline(
      id: "pipeline-1", projectSlug: "gh/acme/app-web", number: 7, ref: "main", refIsTag: false,
      triggerType: "webhook", hasPullRequest: false, createdAt: Date(), state: .running,
      url: URL(string: "https://app.circleci.com/pipelines/github/acme/app-web/7")!, newestWorkflowId: "workflow-1")
    try SourceCache(directory: cacheDirectory).save(Cached(value: [runningPipeline], fetchedAt: Date()), name: "circleci")
    let response = CircleCIResponse()
    response.workflowStatus = "failed"
    let notifier = FakeNotifier()
    let store = makeStore(transport: try circleciTransport(response), notifier: notifier, cacheDirectory: cacheDirectory)
    store.loadCache()
    #expect(store.pipelines?.first?.state == .running)
    await store.refresh()
    #expect(notifier.postedEvents.isEmpty)
  }

  @Test func failedFetchPostsNothingAndKeepsTheBaseline() async throws {
    let response = CircleCIResponse()
    let notifier = FakeNotifier()
    let store = makeStore(transport: try circleciTransport(response), notifier: notifier)
    await store.refresh()
    response.statusCode = 500
    await store.refresh()
    #expect(store.circleciStatus == .failed(.unexpected("HTTP 500")))
    #expect(notifier.postedEvents.isEmpty)
    response.statusCode = 200
    response.workflowStatus = "failed"
    await store.refresh()
    #expect(notifier.postedEvents.map(\.kind) == [.ciFailed])
  }

  @Test func kindThatIsOffIsNotPosted() async throws {
    let response = CircleCIResponse()
    let notifier = FakeNotifier()
    let store = makeStore(
      transport: try circleciTransport(response), notifier: notifier, enabledKinds: [.ciPassed, .ciNeedsApproval])
    await store.refresh()
    response.workflowStatus = "failed"
    await store.refresh()
    #expect(notifier.postedEvents.isEmpty)
  }

  @Test func dismissedPipelinePostsNothing() async throws {
    let response = CircleCIResponse()
    response.workflowStatus = "failed"
    let notifier = FakeNotifier()
    let store = makeStore(transport: try circleciTransport(response), notifier: notifier)
    await store.refresh()
    let failedItem = try #require(store.sections.flatMap(\.items).first { $0.dismissal != nil && $0.title == "main" })
    store.dismiss(failedItem)
    response.workflowStatus = "running"
    await store.refresh()
    response.workflowStatus = "failed"
    await store.refresh()
    #expect(notifier.postedEvents.isEmpty)
  }
}

struct NotificationSettingsKeysTests {
  @Test func everyKindIsOnWhenNothingIsSaved() {
    let defaults = UserDefaults(suiteName: "tower-notify-\(UUID().uuidString)")!
    #expect(NotificationSettingsKeys.enabledKinds(defaults: defaults) == Set(NotificationEventKind.allCases))
  }

  @Test func kindSavedAsOffIsLeftOut() {
    let defaults = UserDefaults(suiteName: "tower-notify-\(UUID().uuidString)")!
    defaults.set(false, forKey: NotificationSettingsKeys.key(.ciPassed))
    #expect(!NotificationSettingsKeys.enabledKinds(defaults: defaults).contains(.ciPassed))
    #expect(NotificationSettingsKeys.enabledKinds(defaults: defaults).count == 4)
  }
}

struct UserNotificationRequestTests {
  @Test func requestCarriesTheEventIdTextAndURL() {
    let event = NotificationEvent(
      kind: .approvalReceived, id: "approvalReceived:pr:app-web#1:approvals=1", body: "Add login\napp-web #1",
      url: URL(string: "https://github.com/acme/app-web/pull/1")!)
    let request = UserNotificationNotifier.request(for: event)
    #expect(request.identifier == event.id)
    #expect(request.content.title == "Approved")
    #expect(request.content.body == "Add login\napp-web #1")
    #expect(UserNotificationNotifier.url(fromUserInfo: request.content.userInfo) == event.url)
  }
}
