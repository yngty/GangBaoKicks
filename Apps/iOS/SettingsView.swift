import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.dismiss) private var dismiss

    private let durationOptions: [TimeInterval] = [30, 45, 60, 90, 120].map { TimeInterval($0 * 60) }
    private let duplicateOptions: [TimeInterval] = [60, 120, 300, 600]

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedThemeBackground(theme: themeController.selectedTheme)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        themeSection
                        countingSection
                        privacySection
                    }
                    .padding(18)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                        .foregroundStyle(themeController.selectedTheme.primary)
                }
            }
        }
    }

    private var themeSection: some View {
        SettingsCard(theme: themeController.selectedTheme) {
            Text("settings.theme")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeController.selectedTheme = theme
                    } label: {
                        HStack(spacing: 12) {
                            HStack(spacing: 5) {
                                Circle().fill(theme.primary)
                                Circle().fill(theme.secondary)
                                Circle().fill(theme.background)
                            }
                            .frame(width: 54, height: 18)

                            Text(theme.localizedName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if themeController.selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.primary)
                            }
                        }
                    }
                    .buttonStyle(SettingsRowButtonStyle(theme: themeController.selectedTheme, isSelected: themeController.selectedTheme == theme))
                }
            }
        }
    }

    private var countingSection: some View {
        SettingsCard(theme: themeController.selectedTheme) {
            Text("settings.counting")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Text("settings.duration")
                    .font(.subheadline.weight(.semibold))
                WrappedChips {
                    ForEach(durationOptions, id: \.self) { option in
                        Button(option.formattedMinutes) {
                            store.targetDuration = option
                        }
                        .buttonStyle(SettingsChipStyle(isSelected: store.targetDuration == option, theme: themeController.selectedTheme))
                    }
                }
            }

            Toggle("settings.filterRepeats", isOn: $store.duplicateFilteringEnabled)
                .tint(themeController.selectedTheme.primary)

            Toggle("settings.autoStop", isOn: $store.autoStopWhenTargetReached)
                .tint(themeController.selectedTheme.primary)

            VStack(alignment: .leading, spacing: 10) {
                Text("settings.duplicateInterval")
                    .font(.subheadline.weight(.semibold))
                WrappedChips {
                    ForEach(duplicateOptions, id: \.self) { option in
                        Button(option.formattedMinutes) {
                            store.duplicateInterval = option
                        }
                        .buttonStyle(SettingsChipStyle(isSelected: store.duplicateInterval == option, theme: themeController.selectedTheme))
                        .disabled(!store.duplicateFilteringEnabled)
                    }
                }
                .opacity(store.duplicateFilteringEnabled ? 1 : 0.45)
            }
        }
    }

    private var privacySection: some View {
        SettingsCard(theme: themeController.selectedTheme) {
            Text("settings.privacy")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let theme: AppTheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingsRowButtonStyle: ButtonStyle {
    let theme: AppTheme
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .frame(minHeight: 48)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(isSelected ? theme.background : theme.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SettingsChipStyle: ButtonStyle {
    let isSelected: Bool
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            .background(isSelected ? theme.primary : theme.background.opacity(0.8), in: Capsule())
            .foregroundStyle(isSelected ? .white : theme.primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct WrappedChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { content }
            VStack(alignment: .leading, spacing: 8) { content }
        }
    }
}
