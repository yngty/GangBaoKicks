import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var syncService: WatchSyncService
    @EnvironmentObject private var themeController: ThemeController
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminderTimes: [ReminderClockTime] = [ReminderClockTime.defaultEvening]
    @State private var reminderEnabled = false
    @State private var hasLoadedReminderPreferences = false
    @State private var exportURL: URL?
    @State private var toast: ToastState?
    @State private var confirmation: ConfirmationState?
    @State private var showingSettings = false
    @State private var timeReachedSessionID: UUID?
    @State private var currentDate = Date.now
    @State private var kickPadTapBounce = false
    @State private var kickPadRipple = false
    @State private var kickPadRippleCenter: CGPoint = .zero
    @State private var kickPadTouchTracking = false
    @State private var kickCountPop = false
    @FocusState private var isNoteEditorFocused: Bool

    private let reminderEnabledKey = "gangbao.reminderEnabled"
    private let reminderTimesKey = "gangbao.reminderTimes"
    private let maxReminderTimes = 5

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
                .scrollDismissesKeyboard(.immediately)
                .scrollBounceBehavior(.always, axes: .vertical)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissNoteEditor()
                    }
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("settings.done") {
                        dismissNoteEditor()
                    }
                }
            }
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
            .onAppear {
                prepareExport()
                loadReminderPreferencesIfNeeded()
            }
            .onChange(of: store.sessions) { _, _ in prepareExport() }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                refreshTimeline(at: date)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshTimeline(at: .now)
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
                    .scaleEffect(kickCountPop ? 1.06 : 1)
                    .accessibilityLabel(Text("counter.effective"))
                    .accessibilityValue("\(session.effectiveCount)")

                Text(String(format: NSLocalizedString("counter.observe", comment: "Observation time"), session.duration(at: currentDate).formattedDuration, session.targetDurationText))
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                ProgressView(value: session.progress(at: currentDate))
                    .tint(theme.primary)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                StatPill(title: "counter.effective", value: "\(session.effectiveCount)", theme: theme)
                StatPill(title: "counter.raw", value: "\(session.rawTapCount)", theme: theme)
            }

            Button {
                dismissNoteEditor()
                triggerKickPadTapEffects()
                recordKick()
            } label: {
                GeometryReader { geometry in
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.24))
                            .frame(width: 40, height: 40)
                            .position(kickPadRippleCenter == .zero ? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) : kickPadRippleCenter)
                            .scaleEffect(kickPadRipple ? 5.0 : 0.1)
                            .opacity(kickPadRipple ? 0 : 0.38)

                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 34, weight: .semibold))

                            Text("counter.kick")
                                .font(.title3.weight(.bold))
                        }
                    }
                    .onAppear {
                        if kickPadRippleCenter == .zero {
                            kickPadRippleCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 124)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .scaleEffect(kickPadTapBounce ? 0.94 : 1)
            .buttonStyle(KickPadButtonStyle(theme: theme))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard !kickPadTouchTracking else { return }
                        kickPadTouchTracking = true
                        kickPadRippleCenter = value.location
                    }
                    .onEnded { _ in
                        kickPadTouchTracking = false
                    }
            )

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
        VStack(alignment: .trailing, spacing: 8) {
            TextField("details.note", text: Binding(
                get: { store.activeSession?.note ?? "" },
                set: { note in
                    store.updateActiveSession(note: note, tags: store.activeSession?.tags ?? [])
                    syncService.publish(store.syncPayload)
                }
            ), axis: .vertical)
            .focused($isNoteEditorFocused)
            .submitLabel(.done)
            .onSubmit {
                dismissNoteEditor()
            }
            .lineLimit(2...4)
            .padding(12)
            .background(theme.background.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(session.id != store.activeSession?.id)

            if isNoteEditorFocused {
                Button("settings.done") {
                    dismissNoteEditor()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
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
                .onChange(of: reminderEnabled) { _, _ in
                    persistReminderPreferences()
                    syncReminderScheduling()
                }

            if reminderEnabled {
                VStack(spacing: 10) {
                    ForEach(reminderTimes.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            DatePicker(
                                "reminder.time",
                                selection: reminderTimeBinding(at: index),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                removeReminderTime(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(reminderTimes.count > 1 ? Color.red : Color.secondary)
                            .disabled(reminderTimes.count <= 1)
                            .accessibilityLabel(Text("reminder.removeTime"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    Button {
                        addReminderTime()
                    } label: {
                        Label("reminder.addTime", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.primary)
                    .background(theme.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(reminderTimes.count >= maxReminderTimes)
                    .opacity(reminderTimes.count >= maxReminderTimes ? 0.45 : 1)
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

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("history.title")
                    .font(.headline)
                Spacer()
                if !store.sortedSessions.isEmpty {
                    NavigationLink {
                        AllHistoryView(allSessions: store.sortedSessions, theme: theme)
                    } label: {
                        HStack(spacing: 4) {
                            Text("history.viewAll")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.sortedSessions.isEmpty {
                ContentUnavailableView("history.empty", systemImage: "clock.badge.questionmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ForEach(store.sortedSessions.prefix(8)) { session in
                    NavigationLink {
                        SessionDetailView(session: session, theme: theme)
                    } label: {
                        HistoryRow(session: session, theme: theme)
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

        if result == .counted {
            triggerSuccessfulKickFeedback()
        }

        if result == .duplicate {
            triggerDuplicateKickFeedback()
            showToast(NSLocalizedString("counter.duplicateToast", comment: "Duplicate toast"))
        }
    }

    private func triggerKickPadTapEffects() {
        triggerKickPadTapBounce()
        triggerKickPadRipple()
    }

    private func triggerKickPadTapBounce() {
        withAnimation(.easeOut(duration: 0.08)) {
            kickPadTapBounce = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.08))
            withAnimation(.spring(response: 0.24, dampingFraction: 0.62)) {
                kickPadTapBounce = false
            }
        }
    }

    private func triggerKickPadRipple() {
        kickPadRipple = false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(10))
            withAnimation(.easeOut(duration: 0.45)) {
                kickPadRipple = true
            }

            try? await Task.sleep(for: .seconds(0.45))
            kickPadRipple = false
        }
    }

    private func triggerSuccessfulKickFeedback() {
        withAnimation(.spring(response: 0.16, dampingFraction: 0.56)) {
            kickCountPop = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
                kickCountPop = false
            }
        }

        guard store.hapticFeedbackEnabled else { return }

        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.95)
        #endif
    }

    private func triggerDuplicateKickFeedback() {
        guard store.hapticFeedbackEnabled else { return }

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
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

    private func refreshTimeline(at date: Date) {
        currentDate = date
        handleCountdownTick(at: date)
    }

    private func showToast(_ message: String) {
        let state = ToastState(message: message)
        toast = state
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            if toast == state { toast = nil }
        }
    }

    private func loadReminderPreferencesIfNeeded() {
        guard !hasLoadedReminderPreferences else { return }
        hasLoadedReminderPreferences = true

        let defaults = UserDefaults.standard
        reminderEnabled = defaults.object(forKey: reminderEnabledKey) as? Bool ?? false

        if let data = defaults.data(forKey: reminderTimesKey),
           let storedTimes = try? JSONDecoder().decode([ReminderClockTime].self, from: data),
           !storedTimes.isEmpty {
            reminderTimes = normalizedReminderTimes(from: storedTimes)
        } else {
            reminderTimes = [ReminderClockTime.defaultEvening]
        }

        syncReminderScheduling()
    }

    private func persistReminderPreferences() {
        let defaults = UserDefaults.standard
        let normalized = normalizedReminderTimes(from: reminderTimes)
        reminderTimes = normalized
        defaults.set(reminderEnabled, forKey: reminderEnabledKey)
        defaults.set(try? JSONEncoder().encode(normalized), forKey: reminderTimesKey)
    }

    private func syncReminderScheduling() {
        if reminderEnabled {
            Task {
                try? await ReminderScheduler.scheduleDailyReminders(times: reminderTimes)
            }
        } else {
            ReminderScheduler.cancelDailyReminders()
        }
    }

    private func reminderTimeBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                let time = reminderTimes[index]
                let components = DateComponents(hour: time.hour, minute: time.minute)
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newDate in
                updateReminderTime(at: index, to: newDate)
            }
        )
    }

    private func updateReminderTime(at index: Int, to date: Date) {
        guard reminderTimes.indices.contains(index) else { return }
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminderTimes[index] = ReminderClockTime(hour: components.hour ?? 20, minute: components.minute ?? 0)
        persistReminderPreferences()
        syncReminderScheduling()
    }

    private func addReminderTime() {
        guard reminderTimes.count < maxReminderTimes else { return }

        let existing = Set(reminderTimes.map(\.minutesFromMidnight))
        let start = reminderTimes.last?.minutesFromMidnight ?? ReminderClockTime.defaultEvening.minutesFromMidnight
        var candidate = start
        var attempts = 0

        while attempts < 24 {
            candidate = (candidate + 60) % (24 * 60)
            if !existing.contains(candidate) { break }
            attempts += 1
        }

        reminderTimes.append(ReminderClockTime(hour: candidate / 60, minute: candidate % 60))
        persistReminderPreferences()
        syncReminderScheduling()
    }

    private func removeReminderTime(at index: Int) {
        guard reminderTimes.indices.contains(index), reminderTimes.count > 1 else { return }
        reminderTimes.remove(at: index)
        persistReminderPreferences()
        syncReminderScheduling()
    }

    private func normalizedReminderTimes(from times: [ReminderClockTime]) -> [ReminderClockTime] {
        let unique = Array(Set(times))
        return unique.sorted { lhs, rhs in
            lhs.minutesFromMidnight < rhs.minutesFromMidnight
        }
    }

    private func prepareExport() {
        exportURL = try? CSVExporter.makeFileURL(from: store.sessions)
    }

    private func dismissNoteEditor() {
        isNoteEditorFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

private struct AllHistoryView: View {
    let allSessions: [KickSession]
    let theme: AppTheme

    @State private var displayedCount = 30
    private let pageSize = 30

    private var displayedSessions: [KickSession] {
        Array(allSessions.prefix(displayedCount))
    }

    private var hasMore: Bool {
        displayedCount < allSessions.count
    }

    var body: some View {
        ZStack {
            AnimatedThemeBackground(theme: theme)

            if allSessions.isEmpty {
                ContentUnavailableView("history.empty", systemImage: "clock.badge.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            } else {
                List {
                    ForEach(displayedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session, theme: theme)
                        } label: {
                            HistoryRow(session: session, theme: theme)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            loadMoreIfNeeded(currentID: session.id)
                        }
                    }

                    if hasMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 12)
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("history.allTitle")
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
    }

    private func loadMoreIfNeeded(currentID: UUID) {
        guard hasMore, currentID == displayedSessions.last?.id else { return }
        displayedCount = min(displayedCount + pageSize, allSessions.count)
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
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PulseButtonStyle(tint: theme.primary))

                Button {
                    state.secondaryAction()
                } label: {
                    Text(state.secondaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ConfirmationSecondaryButtonStyle(theme: theme))

                if let destructiveTitle = state.destructiveTitle, let destructiveAction = state.destructiveAction {
                    Button(role: .destructive, action: destructiveAction) {
                        Text(destructiveTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ConfirmationDestructiveButtonStyle())
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

private struct HistoryRow: View {
    let session: KickSession
    let theme: AppTheme

    var body: some View {
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

private struct ConfirmationSecondaryButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 11)
            .frame(minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(theme.background.opacity(configuration.isPressed ? 0.64 : 0.94), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(theme.primary)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(color: theme.primary.opacity(configuration.isPressed ? 0.07 : 0.13), radius: configuration.isPressed ? 4 : 7, y: configuration.isPressed ? 2 : 4)
    }
}

private struct ConfirmationDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 11)
            .frame(minHeight: 52)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(Color.red.opacity(configuration.isPressed ? 0.16 : 0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .foregroundStyle(.red)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct KickPadButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(theme.primary.opacity(configuration.isPressed ? 0.88 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: theme.primary.opacity(configuration.isPressed ? 0.14 : 0.28), radius: configuration.isPressed ? 6 : 14, y: configuration.isPressed ? 3 : 8)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
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
        ZStack {
            AnimatedThemeBackground(theme: theme)

            ScrollView {
                VStack(spacing: 14) {
                    DetailSectionCard(title: "details.title", theme: theme) {
                        ThemedDetailRow(title: "counter.effective", value: "\(session.effectiveCount)", theme: theme, emphasize: true)
                        ThemedDetailRow(title: "counter.raw", value: "\(session.rawTapCount)", theme: theme)
                        ThemedDetailRow(title: "counter.duplicates", value: "\(session.duplicateCount)", theme: theme)
                        ThemedDetailRow(title: "details.targetDuration", value: session.targetDurationText, theme: theme)
                        ThemedDetailRow(title: "details.actualDuration", value: session.durationText, theme: theme, secondaryEmphasis: true)
                    }

                    DetailSectionCard(title: "details.tags", theme: theme) {
                        if session.tags.isEmpty {
                            Text("details.noTags")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(session.tags.map(\.localizedName).joined(separator: " · "))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }

                    DetailSectionCard(title: "details.note", theme: theme) {
                        Text(session.note.isEmpty ? NSLocalizedString("details.noNote", comment: "No note") : session.note)
                            .foregroundStyle(session.note.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(session.dateText)
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.primary)
    }
}

private struct DetailSectionCard<Content: View>: View {
    let title: LocalizedStringKey
    let theme: AppTheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primary)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .background(theme.surface.opacity(0.76), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: theme.primary.opacity(0.07), radius: 16, y: 8)
    }
}

private struct ThemedDetailRow: View {
    let title: LocalizedStringKey
    let value: String
    let theme: AppTheme
    var emphasize = false
    var secondaryEmphasis = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(emphasize ? .headline.weight(.semibold) : .subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(
                    emphasize ? theme.primary : (secondaryEmphasis ? theme.primary.opacity(0.82) : Color.primary)
                )
        }
    }
}
