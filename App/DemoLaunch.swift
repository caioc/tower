#if DEBUG
import Core
import Foundation
import os

// Debug-only launch argument: `-demo <scenario>` shows fixed fake data and makes no network calls.
enum DemoLaunch {
  static let scenario: DemoScenario? = {
    guard let launchValue = DemoScenario.launchValue(arguments: ProcessInfo.processInfo.arguments) else { return nil }
    if DemoScenario.Name(rawValue: launchValue) == nil {
      let validNames = DemoScenario.Name.allCases.map(\.rawValue).joined(separator: ", ")
      Logger(subsystem: "dev.wilsonfaustino.Tower", category: "demo").error(
        "Unknown demo scenario \"\(launchValue, privacy: .public)\". Valid names: \(validNames, privacy: .public). Using typical."
      )
    }
    return DemoScenario(name: DemoScenario.Name(launchValue: launchValue), now: .now)
  }()

  // Settings tests and Reconnect use real credentials, so demo mode turns them off.
  static let isActive = scenario != nil
}
#else
enum DemoLaunch {
  static let isActive = false
}
#endif
