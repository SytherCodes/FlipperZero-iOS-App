import Core
import Inject
import Peripheral
import Foundation
import Combine

@MainActor
class DeviceViewModel: ObservableObject {
    @Published var appState: AppState = .shared
    private var disposeBag: DisposeBag = .init()

    @Published var showPairingIssueAlert = false
    @Published var showUnsupportedVersionAlert = false

    @Published var flipper: Flipper?
    @Published var status: DeviceStatus = .noDevice {
        didSet {
            switch status {
            case .pairingIssue: showPairingIssueAlert = true
            case .unsupportedDevice: showUnsupportedVersionAlert = true
            default: break
            }
        }
    }

    var protobufVersion: String? {
        guard flipper?.isUnsupported == false else {
            return nil
        }
        return flipper?.information?.protobufRevision ?? "-"
    }

    var firmwareVersion: String {
        guard let info = flipper?.information else {
            return ""
        }

        let version = info
            .softwareRevision
            .split(separator: " ")
            .dropFirst()
            .prefix(1)
            .joined()

        return .init(version)
    }

    var firmwareBuild: String {
        guard let info = flipper?.information else {
            return ""
        }

        let build = info
            .softwareRevision
            .split(separator: " ")
            .suffix(1)
            .joined(separator: " ")

        return .init(build)
    }

    var internalSpace: String? {
        guard flipper?.isUnsupported == false else {
            return nil
        }
        return flipper?.storage?.internal?.description ?? ""
    }

    var externalSpace: String? {
        guard flipper?.isUnsupported == false else {
            return nil
        }
        return flipper?.storage?.external?.description ?? ""
    }

    init() {
        appState.$flipper
            .receive(on: DispatchQueue.main)
            .assign(to: \.flipper, on: self)
            .store(in: &disposeBag)

        appState.$status
            .receive(on: DispatchQueue.main)
            .assign(to: \.status, on: self)
            .store(in: &disposeBag)
    }

    func showWelcomeScreen() {
        appState.forgetDevice()
        appState.isFirstLaunch = true
    }

    func sync() {
        Task { await appState.synchronize() }
    }
}

extension String {
    static var noDevice: String { "No device" }
    static var unknown: String { "Unknown" }
}

extension StorageSpace: CustomStringConvertible {
    public var description: String {
        "\(free.hr) / \(total.hr)"
    }
}

extension Int {
    var hr: String {
        let formatter = ByteCountFormatter()
        return formatter.string(fromByteCount: Int64(self))
    }
}