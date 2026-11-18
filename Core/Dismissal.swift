import Foundation

// What a dismissible row carries, so the store knows which dismissal list to add it to.
public enum Dismissal: Hashable, Sendable {
  case pipeline(PipelineDismissal)
  case pullRequest(PullRequestDismissal)
}

// Hides one review request only while the request time and the head commit stay the same,
// so a new review request or a new commit shows it again.
public struct PullRequestDismissal: Codable, Hashable, Sendable {
  public var repository: String
  public var number: Int
  public var reviewRequestedAt: Date?
  public var headCommitId: String?

  public init(repository: String, number: Int, reviewRequestedAt: Date?, headCommitId: String?) {
    self.repository = repository
    self.number = number
    self.reviewRequestedAt = reviewRequestedAt
    self.headCommitId = headCommitId
  }
}

extension PullRequest {
  public var dismissal: PullRequestDismissal {
    PullRequestDismissal(
      repository: repository, number: number, reviewRequestedAt: reviewRequestedAt, headCommitId: headCommitId)
  }
}

// Keeps only the dismissals of PRs GitHub still returns as review requests, so the list does not grow.
public func prunedDismissals(
  _ dismissals: Set<PullRequestDismissal>, reviewRequests: [PullRequest]
) -> Set<PullRequestDismissal> {
  let requestedPullRequests = Set(reviewRequests.map { "\($0.repository)#\($0.number)" })
  return dismissals.filter { requestedPullRequests.contains("\($0.repository)#\($0.number)") }
}
