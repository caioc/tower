import SwiftUI

struct GitHubOrganizationsField: View {
  @AppStorage(GitHubSettingsKeys.organizations) private var githubOrganizations = ""

  var body: some View {
    SettingsRow(label: "Organizations") {
      SettingsTextEditor(text: $githubOrganizations)
      SettingsCaption(text: "One per line. Leave empty to show PRs from all organizations.")
    }
  }
}
