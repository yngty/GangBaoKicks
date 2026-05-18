import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var syncService: WatchSyncService
    @EnvironmentObject private var themeController: ThemeController
    @State private var reminderDate = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? .now
    @State private var reminderEnabled = false
    @State private var exportURL: URL?
    @State private var toast: ToastState?
    @State private var confirmation: ConfirmationState?
    @State private var showingSettings = false
    @State private var timeReachedSessionID: UUID?
    @State private var currentDate = Date.now

    private var theme: AppTheme { themeController.selectedTheme }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedThemeBackground(theme: theme)

                ScrollView {
                    VStack(spacing: 16) {
                        topActionBar
                        header
                        counterCard
                        reminderCard
                        historyCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(themeController)
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    ThemedToast(message: toast.message, theme: theme)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 26)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                if let confirmation {
                    ThemedConfirmationView(state: confirmation, theme: theme)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.spring(response: 0.26, dampingFraction: 0.82), value: toast)
            .animation(.spring(response: 0.26, dampingFraction: 0.86), value: confirmation)
            .onAppear(perform: prepareExport)
            .onChange(of: store.sessions) { _, _ in prepareExport() }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                currentDate = date
                handleCountdownTick(at: date)
            }
        }
    }

    private var topActionBar: some View {
        HStack {
            Spacer()

            HStack(spacing: 14) {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(Text("export.title"))
                }

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("settings.title"))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(.thinMaterial, in: Capsule())
            .background(theme.surface.opacity(0.72), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: theme.primary.opacity(0.08), radius: 16, y: 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("app.title")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(store.activeSession == nil ? "counter.ready" : "counter.kickCount")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(store.activeSession?.timeRangeText ?? currentDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ThemeSwatch(theme: theme)
        }
    }

    private var counterCard: some View {
        VStack(spacing: 18) {
            if let session = store.activeSession {
                activeCounter(session)
            } else {
                inactiveCounter
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(theme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(theme.primary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: theme.primary.opacity(0.07), radius: 18, y: 8)
    }

    private func activeCounter(_ session: KickSession) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("\(session.effectiveCount)")
                    .font(.system(size: 86, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.primary)
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("counter.effective"))
                    .accessibilityValue("\(session.effectiveCount)")

                Text(String(format: NSLocalizedString("counter.observe", comment: "Observation time"), session.duration(at: currentDate).formattedDuration, session.targetDurationText))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                ProgressView(value: session.progress(at: currentDate))
                    .tint(theme.primary)
            }

            HStack(spacing: 10) {
                StatPill(title: "counter.effective", value: "\(session.effectiveCount)", theme: theme)
                StatPill(title: "counter.raw", value: "\(session.rawTapCount)", theme: theme)
            }

            Button {
                recordKick()
            } label: {
                Label("counter.kick", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PulseButtonStyle(tint: theme.primary))

            HStack(spacing: 10) {
                Button {
                    store.undoLastTap()
                    syncService.publish(store.syncPayload)
                } label: {
                    Label("counter.undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(theme: theme))
                .disabled(session.events.isEmpty)

                Button {
                    askToEnd(session)
                } label: {
                    Label("counter.end", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle(theme: theme))
            }

            noteEditor(session)
            tagSelector(session)
        }
    }

    private var inactiveCounter: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.primary)
                .symbolRenderingMode(.hierarchical)

            Text("counter.ready")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                store.startSession()
                timeReachedSessionID = nil
                syncService.publish(store.syncPayload)
            } label: {
                Label("counter.start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PulseButtonStyle(tint: theme.primary))
        }
    }

    private func noteEditor(_ session: KickSession) -> some View {
        TextField("details.note", text: Binding(
            get: { store.activeSession?.note ?? "" },
            set: { note in
                store.updateActiveSession(note: note, tags: store.activeSession?.tags ?? [])
                syncService.publish(store.syncPayload)
            }
        ), axis: .vertical)
        .lineLimit(2...4)
        .padding(12)
        .background(theme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .disabled(session.id != store.activeSession?.id)
    }

    private func tagSelector(_ session: KickSession) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(KickTag.allCases) { tag in
                let selected = session.tags.contains(tag)
                Button {
                    toggleTag(tag, in: session)
                } label: {
                    Text(tag.localizedName)
                }
                .buttonStyle(ChipButtonStyle(isSelected: selected, theme: theme))
            }
        }
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("reminder.title")
                .font(.headline)
            Toggle("reminder.daily", isOn: $reminderEnabled)
                .tint(theme.primary)
                .onChange(of: reminderEnabled) { _, enabled in
                    if enabled {
                        scheduleReminder()
                    } else {
                        ReminderScheduler.cancelDailyReminder()
                    }
                }

            DatePicker("reminder.time", selection: $reminderDate, displayedComponents: .hourAndMinute)
                .disabled(!reminderEnabled)
                .onChange(of: reminderDate) { _, _ in
                    if reminderEnabled { scheduleReminder() }
                }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(theme.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("history.title")
                .font(.headline)

            if store.sortedSessions.isEmpty {
                ContentUnavailableView("history.empty", systemImage: "clock.badge.questionmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ForEach(store.sortedSessions.prefix(8)) { session in
                    NavigationLink {
                        SessionDetailView(session: session, theme: theme)
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.dateText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(String(format: NSLocalizedString("history.summary", comment: "Session summary"), session.effectiveCount, session.duplicateCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.effectiveCount)")
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(theme.primary)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(theme.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func recordKick() {
        let result = store.addKick()
        syncService.publish(store.syncPayload)

        if result == .duplicate {
            showToast(NSLocalizedString("counter.duplicateToast", comment: "Duplicate toast"))
        }
    }

    private func askToEnd(_ session: KickSession) {
        let isEmpty = session.rawTapCount == 0
        confirmation = ConfirmationState(
            title: NSLocalizedString(isEmpty ? "counter.emptySessionTitle" : "counter.endTitle", comment: "End confirmation title"),
            message: NSLocalizedString(isEmpty ? "counter.emptySessionMessage" : "counter.endMessage", comment: "End confirmation message"),
            primaryTitle: NSLocalizedString("counter.save", comment: "Save"),
            secondaryTitle: NSLocalizedString("counter.keepCounting", comment: "Keep counting"),
            destructiveTitle: isEmpty ? NSLocalizedString("counter.discard", comment: "Discard") : nil,
            primaryAction: {
                finishSession()
            },
            secondaryAction: {
                confirmation = nil
            },
            destructiveAction: isEmpty ? {
                store.discardActiveSession()
                syncService.publish(store.syncPayload)
                confirmation = nil
            } : nil
        )
    }

    private func finishSession(at date: Date = .now) {
        store.endSession(at: date)
        syncService.publish(store.syncPayload)
        confirmation = nil
        showToast(NSLocalizedString("counter.savedToast", comment: "Saved toast"))
    }

    private func toggleTag(_ tag: KickTag, in session: KickSession) {
        var tags = session.tags
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }
        store.updateActiveSession(note: session.note, tags: tags)
        syncService.publish(store.syncPayload)
    }

    private func handleCountdownTick(at date: Date) {
        guard let session = store.activeSession,
              session.duration(at: date) >= session.targetDuration,
              timeReachedSessionID != session.id else { return }
        timeReachedSessionID = session.id

        if store.autoStopWhenTargetReached {
            let endDate = session.startedAt.addingTimeInterval(session.targetDuration)
            finishSession(at: endDate)
            showToast(NSLocalizedString("counter.autoStoppedToast", comment: "Auto-stopped toast"))
        } else {
            showToast(NSLocalizedString("counter.doneToast", comment: "Time reached toast"))
        }
    }

    private func showToast(_ message: String) {
        let state = ToastState(message: message)
        toast = state
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            if toast == state { toast = nil }
        }
    }

    private func scheduleReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        Task {
            try? await ReminderScheduler.scheduleDailyReminder(hour: components.hour ?? 20, minute: components.minute ?? 0)
        }
    }

    private func prepareExport() {
        exportURL = try? CSVExporter.makeFileURL(from: store.sessions)
    }
}

private struct ToastState: Equatable, Identifiable {
    let id = UUID()
    let message: String
}

private struct ConfirmationState: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let primaryTitle: String
    let secondaryTitle: String
    let destructiveTitle: String?
    let primaryAction: () -> Void
    let secondaryAction: () -> Void
    let destructiveAction: (() -> Void)?

    static func == (lhs: ConfirmationState, rhs: ConfirmationState) -> Bool {
        lhs.id == rhs.id
    }
}

private struct ThemedToast: View {
    let message: String
    let theme: AppTheme

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.primary.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: theme.primary.opacity(0.22), radius: 16, y: 8)
    }
}

private struct ThemedConfirmationView: View {
    let state: ConfirmationState
    let theme: AppTheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.20).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(state.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    state.primaryAction()
                } label: {
                    Text(state.primaryTitle)
                        .padding(.horizontal, 18)
                }
                    .buttonStyle(PulseButtonStyle(tint: theme.primary))

                Button {
                    state.secondaryAction()
                } label: {
                    Text(state.secondaryTitle)
                        .padding(.horizontal, 18)
                }
                    .buttonStyle(SoftButtonStyle(theme: theme))

                if let destructiveTitle = state.destructiveTitle, let destructiveAction = state.destructiveAction {
                    Button(destructiveTitle, role: .destructive, action: destructiveAction)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(20)
            .frame(maxWidth: 330)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: theme.primary.opacity(0.18), radius: 24, y: 10)
            .padding(24)
        }
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(theme.primary)
            Circle().fill(theme.secondary)
            Circle().fill(theme.background)
        }
        .frame(width: 54, height: 18)
    }
}

private struct StatPill: View {
    let title: LocalizedStringKey
    let value: String
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SoftButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 11)
            .frame(minHeight: 48)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(theme.background.opacity(configuration.isPressed ? 0.62 : 0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(theme.primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            .background(isSelected ? theme.primary : theme.background.opacity(0.8), in: Capsule())
            .foregroundStyle(isSelected ? .white : theme.primary)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: width, height: totalHeight + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct SessionDetailView: View {
    let session: KickSession
    let theme: AppTheme

    var body: some View {
        List {
            Section("details.title") {
                LabeledContent("counter.effective", value: "\(session.effectiveCount)")
                LabeledContent("counter.raw", value: "\(session.rawTapCount)")
                LabeledContent("counter.duplicates", value: "\(session.duplicateCount)")
                LabeledContent("details.targetDuration", value: session.targetDurationText)
                LabeledContent("details.actualDuration", value: session.durationText)
            }

            Section("details.tags") {
                if session.tags.isEmpty {
                    Text("details.noTags")
                        .foregroundStyle(.secondary)
                } else {
                    Text(session.tags.map(\.localizedName).joined(separator: " · "))
                }
            }

            Section("details.note") {
                Text(session.note.isEmpty ? NSLocalizedString("details.noNote", comment: "No note") : session.note)
                    .foregroundStyle(session.note.isEmpty ? .secondary : .primary)
            }
        }
        .navigationTitle(session.dateText)
        .tint(theme.primary)
    }
}
