import Combine
import Inject
import Foundation

public class Archive: ObservableObject {
    public static let shared: Archive = .init()

    @Inject var storage: ArchiveStorage
    @Inject var synchronization: SynchronizationProtocol

    var start: Date = .init()
    @Published public var isSynchronizing = false {
        didSet {
            switch isSynchronizing {
            case true: start = .init()
            case false: print(Date().timeIntervalSince(start))
            }
        }
    }

    @Published public var items: [ArchiveItem] = [] {
        didSet {
            storage.items = items
        }
    }

    private init() {
        items = storage.items
    }

    func getManifest() -> Manifest {
        var items = [Manifest.Item]()
        for item in self.items.filter({ $0.status != .deleted }) {
            items.append(.init(path: item.path, hash: item.hash))
        }
        return .init(items: items)
    }

    public func find(_ id: ArchiveItem.ID) -> ArchiveItem? {
        items.first { $0.id == id }
    }

    public func upsert(_ item: ArchiveItem) {
        items.removeAll { $0.id == item.id }
        items.append(item)
    }

    public func delete(_ item: ArchiveItem) {
        updateStatus(of: item, to: .deleted)
    }

    public func delete(_ id: ArchiveItem.ID) {
        if let item = find(id) {
            updateStatus(of: item, to: .deleted)
        }
    }

    public func wipe(_ item: ArchiveItem) {
        items.removeAll { $0.id == item.id }
    }

    public func wipe(_ id: ArchiveItem.ID) {
        items.removeAll { $0.id == id }
    }

    public func rename(_ id: ArchiveItem.ID, to name: String) {
        if let item = find(id) {
            let newItem = item.rename(to: .init(name))
            items.removeAll { $0.id == item.id }
            items.append(newItem)
        }
    }

    public func restore(_ item: ArchiveItem) {
        let manifest = getManifest()
        if let exising = manifest[item.path], exising.hash == item.hash {
            updateStatus(of: item, to: .synchronizied)
        } else {
            updateStatus(of: item, to: .imported)
        }
    }

    public func duplicate(_ id: ArchiveItem.ID) -> ArchiveItem? {
        guard let item = find(id) else {
            return nil
        }
        let newName = "\(item.name.value)_\(Date().timestamp)"
        let newItem = item.rename(to: .init(newName))
        items.append(newItem)
        return newItem
    }

    public func favorite(_ id: ArchiveItem.ID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            objectWillChange.send()
            items[index].isFavorite.toggle()
        }
    }

    func updateStatus(of item: ArchiveItem, to status: ArchiveItem.Status) {
        updateStatus(of: item.id, to: status)
    }

    func updateStatus(of id: ArchiveItem.ID, to status: ArchiveItem.Status) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            objectWillChange.send()
            items[index].status = status
        }
    }

    public func importKey(_ item: ArchiveItem) {
        let isExist = items
            .filter { $0.status != .deleted }
            .contains { item.id == $0.id && item.content == $0.content }

        if !isExist {
            var item = item
            item.status = .imported
            upsert(item)
        }
    }

    public func syncWithDevice() async {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        defer { isSynchronizing = false }

        do {
            try await synchronization.syncWithDevice()
        } catch {
            print("syncronization error", error)
        }
    }
}

fileprivate extension Date {
    var timestamp: Int {
        Int(Date().timeIntervalSince1970)
    }
}
