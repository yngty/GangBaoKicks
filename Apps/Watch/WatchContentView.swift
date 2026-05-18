import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchContentView: View {
    @EnvironmentObject private var store: KickStore
    @EnvironmentObject private var syncService: WatchSyncService
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 10) {
                    if let session = store.activeSession {
                        activeView(session, at: context.date)
                    } else {
                        inactiveView
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("watch.title")
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                handleCountdownTick(at: date)
            }
        }
    }

    private func activeView(_ session: KickSession, at date: Date) -> some View {
        VStack(spacing: 10) {
            Text("\(session.effectiveCount)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(GangBaoStyle.accent)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .accessibilityLabel(Text("counter.effective"))
                .accessibilityValue("\(session.effectiveCount)")

            Text(session.duration(at: date).formattedDuration)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ProgressView(value: session.progress(at: date))
                .tint(GangBaoStyle.accent)

            Button {
                recordKick()
            } label: {
                Label("counter.kick", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GangBaoStyle.accent)

            Button {
                store.endSession()
                syncService.publish(store.syncPayload)
            } label: {
                Label("counter.end", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let notice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
    }

    private var inactiveView: some View {
        VStack(spacing: 12) {
            Text("counter.ready")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                store.startSession()
                syncService.publish(store.syncPayload)
            } label: {
                Label("counter.start", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GangBaoStyle.accent)

            if let latest = store.sortedSessions.first {
                Text(String(format: NSLocalizedString("history.summary", comment: "Session summary"), latest.effectiveCount, latest.duplicateCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func recordKick() {
        let result = store.addKick()
        syncService.publish(store.syncPayload)

        if result == .duplicate {
            #if os(watchOS)
            WKInterfaceDevice.current().play(.directionDown)
            #endif
            showNotice(NSLocalizedString("counter.duplicateToast", comment: "Duplicate toast"))
        }
    }

    private func handleCountdownTick(at date: Date) {
        guard let session = store.activeSession,
              store.autoStopWhenTargetReached,
              session.duration(at: date) >= session.targetDuration else { return }
        let endDate = session.startedAt.addingTimeInterval(session.targetDuration)
        store.endSession(at: endDate)
        syncService.publish(store.syncPayload)
        showNotice(NSLocalizedString("counter.autoStoppedToast", comment: "Auto-stopped toast"))
    }

    private func showNotice(_ message: String) {
        notice = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            if notice == message { notice = nil }
        }
    }
}
