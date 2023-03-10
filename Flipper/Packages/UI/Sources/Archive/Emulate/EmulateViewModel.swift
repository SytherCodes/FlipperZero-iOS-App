import Core
import Inject
import Analytics
import Peripheral
import SwiftUI
import Logging

@MainActor
class EmulateViewModel: ObservableObject {
    private let logger = Logger(label: "emulate-vm")

    @Inject var rpc: RPC
    @Inject var analytics: Analytics

    @Published var item: ArchiveItem
    @Published var isConnected = false
    @Published var isEmulating = false
    @Published var isFlipperAppStarted = false
    @Published var isFlipperAppCancellation = false
    private var emulateTask: Task<Void, Swift.Error>?

    @Published var appState: AppState = .shared
    var disposeBag = DisposeBag()

    init(item: ArchiveItem) {
        self.item = item

        rpc.onAppStateChanged { [weak self] state in
            guard let self = self else { return }
            Task { @MainActor in
                self.onAppStateChanged(state)
            }
        }

        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.isConnected = ($0 == .connected || $0 == .synchronized)
                if $0 == .disconnected {
                    self.resetEmulate()
                }
            }
            .store(in: &disposeBag)
    }

    func onAppStateChanged(_ state: Message.AppState) {
        isFlipperAppStarted = state == .started
        if state == .closed {
            isEmulating = false
            isFlipperAppCancellation = false
        }
        logger.info("flipper app \(state)")
    }

    func waitForAppStartedEvent() async throws {
        while !isFlipperAppStarted {
            try await Task.sleep(nanoseconds: 100 * 1_000_000)
        }
    }

    func startApp() async throws {
        while !isFlipperAppCancellation {
            do {
                try await rpc.appStart(item.fileType.application, args: "RPC")
                return
            } catch let error as Error {
                if error == .application(.systemLocked) {
                    try await Task.sleep(nanoseconds: 100 * 1_000_000)
                    continue
                }
                throw error
            }
        }
    }

    func checkCancellation() throws {
        guard !isFlipperAppCancellation else {
            throw Error.canceled
        }
    }

    func startEmulate() {
        guard !isEmulating else { return }
        isEmulating = true
        emulateTask = Task {
            do {
                try checkCancellation()
                try await startApp()
                try await waitForAppStartedEvent()
                try checkCancellation()
                try await rpc.appLoadFile(item.path)
                if item.fileType == .subghz {
                    try checkCancellation()
                    try await rpc.appButtonPress()
                }
            } catch {
                logger.error("emilating key: \(error)")
            }
            emulateTask = nil
        }
        recordEmulate()
    }

    func stopEmulate() {
        guard isEmulating else { return }
        guard !isFlipperAppCancellation else { return }
        isFlipperAppCancellation = true
        Task {
            _ = await emulateTask?.result
            do {
                try await rpc.appExit()
            } catch {
                logger.error("exiting the app: \(error)")
            }
        }
    }

    func resetEmulate() {
        isEmulating = false
        isFlipperAppStarted = false
        isFlipperAppCancellation = false
    }

    // Analytics

    func recordEmulate() {
        analytics.appOpen(target: .keyEmulate)
    }
}
