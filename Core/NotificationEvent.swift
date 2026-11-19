import Foundation

public enum NotificationEventKind: String, CaseIterable, Sendable {
  case approvalReceived, reviewRequested, ciFailed, ciPassed, ciNeedsApproval

  public var title: String {
    switch self {
    case .approvalReceived: "Approved"
    case .reviewRequested: "Review requested"
    case .ciFailed: "CI failed"
    case .ciPassed: "CI passed"
    case .ciNeedsApproval: "CI needs approval"
    }
  }
}

public struct NotificationEvent: Equatable, Sendable {
  public var kind: NotificationEventKind
  // Built from the kind, the item and the new state, so the same event always gets the same id.
  public var id: String
  public var body: String
  public var url: URL

  public var title: String { kind.title }

  public init(kind: NotificationEventKind, id: String, body: String, url: URL) {
    self.kind = kind
    self.id = id
    self.body = body
    self.url = url
  }
}

// Events between two successful GitHub fetches. A PR that is new in the current snapshot counts as running before.
public func notificationEvents(
  previous: GitHubSnapshot, current: GitHubSnapshot, dismissedPullRequests: Set<PullRequestDismissal>
) -> [NotificationEvent] {
  var events: [NotificationEvent] = []
  let previousAuthoredById = Dictionary(previous.authoredPullRequests.map { ($0.itemId, $0) }) { first, _ in first }
  for pullRequest in current.authoredPullRequests {
    let previousPullRequest = previousAuthoredById[pullRequest.itemId]
    if pullRequest.approvalCount > previousPullRequest?.approvalCount ?? 0 {
      events.append(pullRequest.event(.approvalReceived, state: "approvals=\(pullRequest.approvalCount)"))
    }
    let wasFailing = previousPullRequest?.isFailing ?? false
    let wasPassing = previousPullRequest?.checkState == .success
    if pullRequest.isFailing && !wasFailing {
      events.append(pullRequest.event(.ciFailed, state: pullRequest.headCommitId ?? ""))
    } else if pullRequest.checkState == .success && !wasPassing {
      events.append(pullRequest.event(.ciPassed, state: pullRequest.headCommitId ?? ""))
    }
  }
  let previousRequests = Set(
    previous.reviewRequests.filter { isOpenReviewRequest($0, viewerLogin: previous.viewerLogin) }.map(\.reviewRequestKey))
  for pullRequest in current.reviewRequests
  where isOpenReviewRequest(pullRequest, viewerLogin: current.viewerLogin)
    && !previousRequests.contains(pullRequest.reviewRequestKey)
    && !dismissedPullRequests.contains(pullRequest.dismissal)
  {
    events.append(pullRequest.event(.reviewRequested, state: pullRequest.reviewRequestKey))
  }
  return events
}

// Events between two successful CircleCI fetches. A pipeline that is new in the current list counts as running before.
// Pipelines with a PR are skipped, as in the queue: GitHub checks cover them, and the client does not read their state.
public func notificationEvents(
  previous: [Pipeline], current: [Pipeline], dismissedPipelines: Set<PipelineDismissal>
) -> [NotificationEvent] {
  let previousStateById = Dictionary(previous.map { ($0.id, $0.state) }) { first, _ in first }
  return current.compactMap { pipeline in
    guard !pipeline.hasPullRequest, !dismissedPipelines.contains(pipeline.dismissal) else { return nil }
    let previousState = previousStateById[pipeline.id] ?? .running
    guard pipeline.state != previousState else { return nil }
    let kind: NotificationEventKind
    switch pipeline.state {
    case .failed: kind = .ciFailed
    case .succeeded: kind = .ciPassed
    case .onHold: kind = .ciNeedsApproval
    case .running: return nil
    }
    let repository = pipeline.projectSlug.split(separator: "/").last.map(String.init) ?? pipeline.projectSlug
    return NotificationEvent(
      kind: kind, id: "\(kind.rawValue):pipeline:\(pipeline.id):\(pipeline.newestWorkflowId ?? "")",
      body: "\(pipeline.ref)\n\(repository) #\(pipeline.number)", url: pipeline.url)
  }
}

extension PullRequest {
  // Holds the request time, so a new request on the same PR gives a new key. A new commit does not.
  fileprivate var reviewRequestKey: String {
    "\(itemId):\(reviewRequestedAt.map { "\($0.timeIntervalSince1970)" } ?? "")"
  }

  fileprivate func event(_ kind: NotificationEventKind, state: String) -> NotificationEvent {
    NotificationEvent(
      kind: kind, id: "\(kind.rawValue):\(itemId):\(state)", body: "\(title)\n\(repository) #\(number)", url: url)
  }
}
