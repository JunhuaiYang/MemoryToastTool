import SwiftUI

struct WelcomeGuideView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var settings: AppSettings
    let onSave: () -> Void

    private var language: AppLanguage? {
        settings.languageOverride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localizedString("guide.title", language: language))
                .font(.title2.weight(.semibold))

            Text(localizedString("guide.subtitle", language: language))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                guideRow("1", localizedString("guide.point.gui_only", language: language))
                guideRow("2", localizedString("guide.point.force_quit", language: language))
                guideRow("3", localizedString("guide.point.relaunch", language: language))
                guideRow("4", localizedString("guide.point.no_fake_cleanup", language: language))
            }

            Divider()

            HStack {
                Spacer()
                Button(localizedString("guide.action.acknowledge", language: language)) {
                    settings.hasAcknowledgedSafetyGuide = true
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 320)
    }

    @ViewBuilder
    private func guideRow(_ badge: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(badge)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
