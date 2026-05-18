import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
final class WatchSyncService: NSObject, ObservableObject {
    private weak var store: KickStore?

    func configure(store: KickStore) {
        self.store = store

        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    func publish(_ payload: KickSyncPayload) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported(), let data = try? JSONEncoder().encode(payload) else { return }
        let context: [String: Any] = ["payload": data]
        try? WCSession.default.updateApplicationContext(context)

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil)
        }
        #endif
    }

    private func handle(context: [String: Any]) {
        guard let data = context["payload"] as? Data,
              let payload = try? JSONDecoder().decode(KickSyncPayload.self, from: data) else { return }

        Task { @MainActor in
            self.store?.replace(with: payload)
        }
    }
}

#if canImport(WatchConnectivity)
extension WatchSyncService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task { @MainActor in
            self.handle(context: applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            self.handle(context: message)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
