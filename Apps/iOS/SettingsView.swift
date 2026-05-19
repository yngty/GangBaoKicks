import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.dismiss) private var dismiss

    private let durationOptions: [TimeInterval] = [30, 45, 60, 90].map { TimeInterval($0 * 60) }
    private let duplicateOptions: [TimeInterval] = [60, 120, 300, 600]

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedThemeBackground(theme: themeController.selectedTheme)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        themeSection
                        countingSection
                        privacySection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(themeController.colorSchemePreference.preferredColorScheme)
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
            Label("settings.theme", systemImage: "paintpalette.fill")
                .font(.headline)
                .foregroundStyle(themeController.selectedTheme.primary)

            VStack(alignment: .leading, spacing: 10) {
                Text("settings.appearance")
                    .font(.subheadline.weight(.semibold))

                WrappedChips {
                    ForEach(ThemeColorSchemePreference.allCases) { preference in
                        Button(preference.localizedName) {
                            themeController.colorSchemePreference = preference
                        }
                        .buttonStyle(SettingsChipStyle(isSelected: themeController.colorSchemePreference == preference, theme: themeController.selectedTheme))
                    }
                }
            }

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
            Label("settings.counting", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(themeController.selectedTheme.primary)

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

            VStack(spacing: 8) {
                SettingsToggleRow(title: "settings.filterRepeats", isOn: $store.duplicateFilteringEnabled, theme: themeController.selectedTheme)
                SettingsToggleRow(title: "settings.autoStop", isOn: $store.autoStopWhenTargetReached, theme: themeController.selectedTheme)
                SettingsToggleRow(title: "settings.haptics", isOn: $store.hapticFeedbackEnabled, theme: themeController.selectedTheme)
            }

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
                .opacity(store.duplicateFilteringEnabled ? 1 : 0.42)
                .animation(.easeOut(duration: 0.18), value: store.duplicateFilteringEnabled)
            }
        }
    }

    private var privacySection: some View {
        SettingsCard(theme: themeController.selectedTheme) {
            Label("settings.title", systemImage: "lock.shield")
                .font(.headline)
                .foregroundStyle(themeController.selectedTheme.primary)

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
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: theme.primary.opacity(0.06), radius: 14, y: 6)
    }
}

private struct SettingsToggleRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    let theme: AppTheme

    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(.subheadline.weight(.semibold))
            .tint(theme.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .background(theme.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 40)
            .contentShape(Capsule())
            .background(isSelected ? theme.primary : theme.background.opacity(0.8), in: Capsule())
            .foregroundStyle(isSelected ? .white : theme.primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct WrappedChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayout(spacing: 8) {
            content
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = arrangedRows(sizes: sizes, maxWidth: maxWidth)

        return CGSize(
            width: maxWidth.isFinite ? maxWidth : rows.map(\.width).max() ?? 0,
            height: rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size = sizes[index]
            if origin.x > bounds.minX, origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subviews[index].place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func arrangedRows(sizes: [CGSize], maxWidth: CGFloat) -> [(width: CGFloat, height: CGFloat)] {
        guard !sizes.isEmpty else { return [] }

        var rows: [(width: CGFloat, height: CGFloat)] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for size in sizes {
            let itemWidth = rowWidth == 0 ? size.width : rowWidth + spacing + size.width
            if rowWidth > 0, itemWidth > maxWidth {
                rows.append((rowWidth, rowHeight))
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = itemWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        rows.append((rowWidth, rowHeight))
        return rows
    }
}
