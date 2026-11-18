import SwiftUI

struct StateMessageView: View {
  let symbol: PanelSymbol
  let title: String
  let message: String
  var footnote: String?
  var actionTitle: String?
  var action: (() -> Void)?

  var body: some View {
    VStack(spacing: Theme.Spacing.s) {
      Image(symbol.rawValue)
        .font(.system(size: 28))
        .foregroundStyle(Theme.textSecondary)
        // The title says the same thing, and the asset name would reach VoiceOver.
        .accessibilityHidden(true)
      Text(title).font(Theme.Fonts.stateTitle).foregroundStyle(Theme.textPrimary)
      Text(message).font(Theme.Fonts.stateBody).foregroundStyle(Theme.textSecondary)
      if let footnote {
        Text(footnote).font(Theme.Fonts.rowMeta).foregroundStyle(Theme.textSecondary)
      }
      if let actionTitle, let action {
        Button(actionTitle, action: action).padding(.top, Theme.Spacing.xs)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.vertical, Theme.Spacing.xl)
  }
}

struct AuthBannerView: View {
  let title: String
  let message: String
  var actionTitle = "Reconnect"
  let reconnect: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.s) {
      Image(PanelSymbol.tokenMissing.rawValue)
        .font(.system(size: Theme.Metrics.symbolSize))
        .foregroundStyle(Theme.textSecondary)
        .frame(width: Theme.Metrics.iconColumn)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
        Text(title).font(Theme.Fonts.rowTitle.weight(.semibold)).foregroundStyle(Theme.textPrimary)
        Text(message).font(Theme.Fonts.stateBody).foregroundStyle(Theme.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: Theme.Spacing.s)
      Button(actionTitle, action: reconnect)
    }
    .padding(Theme.Spacing.m)
    .background(Theme.surfaceHover, in: RoundedRectangle(cornerRadius: Theme.Radius.banner))
  }
}

// Shows nothing when the text is nil, so a Settings section can pass an optional hint or error.
struct SettingsCaption: View {
  let text: String?

  var body: some View {
    if let text {
      Text(text)
        .font(.caption)
        .foregroundStyle(Theme.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

// Floats over the bottom of the list after a dismiss. The line under it runs out at the store's undo deadline.
struct UndoBarView: View {
  let title: String
  let expiresAt: Date
  let duration: Duration
  let undo: () -> Void
  @State private var remainingFraction: CGFloat = 1

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: Theme.Spacing.s) {
        Text("Dismissed \u{201C}\(title)\u{201D}")
          .font(Theme.Fonts.rowMeta)
          .foregroundStyle(Theme.textPrimary)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: Theme.Spacing.s)
        Text("\u{2318}Z").font(Theme.Fonts.legend).foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
        Button("Undo", action: undo)
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
      }
      .padding(.leading, Theme.Spacing.m)
      .padding(.trailing, Theme.Spacing.s)
      .padding(.vertical, Theme.Spacing.s)
      GeometryReader { proxy in
        Rectangle()
          .fill(Theme.textSecondary)
          .frame(width: proxy.size.width * remainingFraction)
      }
      .frame(height: 2)
      .accessibilityHidden(true)
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.banner))
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.banner))
    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.banner).stroke(Theme.cardStroke))
    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    // A panel that opens again mid-countdown starts the line at the time left, not full.
    .onAppear {
      let remainingSeconds = max(expiresAt.timeIntervalSinceNow, 0)
      remainingFraction = remainingSeconds / duration.timeInterval
      withAnimation(.linear(duration: remainingSeconds)) { remainingFraction = 0 }
    }
  }
}
