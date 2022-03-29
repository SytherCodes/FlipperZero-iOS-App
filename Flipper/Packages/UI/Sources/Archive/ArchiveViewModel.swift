import Core
import Combine
import Inject
import SwiftUI
import OrderedCollections

@MainActor
class ArchiveViewModel: ObservableObject {
    @Environment(\.presentationMode) var presentationMode
    let appState: AppState = .shared

    @Published var items: [ArchiveItem] = []
    @Published var deleted: [ArchiveItem] = []

    var sortedItems: [ArchiveItem] {
        items.sorted { $0.name < $1.name }
    }

    var favoriteItems: [ArchiveItem] {
        items.filter { $0.isFavorite }
    }

    var selectedItem: ArchiveItem?
    @Published var showInfoView = false
    @Published var showSearchView = false
    @Published var hasImportedItem = false

    var importedItem: ArchiveItem? {
        appState.importQueue.removeFirst()
    }

    var archive: Archive { appState.archive }
    var disposeBag: DisposeBag = .init()

    var groups: OrderedDictionary<ArchiveItem.FileType, Int> {
        [
            .subghz: items.filter { $0.fileType == .subghz }.count,
            .rfid: items.filter { $0.fileType == .rfid }.count,
            .nfc: items.filter { $0.fileType == .nfc }.count,
            .infrared: items.filter { $0.fileType == .infrared }.count,
            .ibutton: items.filter { $0.fileType == .ibutton }.count
        ]
    }

    init() {
        archive.$items
            .receive(on: DispatchQueue.main)
            .assign(to: \.items, on: self)
            .store(in: &disposeBag)

        archive.$deletedItems
            .receive(on: DispatchQueue.main)
            .assign(to: \.deleted, on: self)
            .store(in: &disposeBag)

        appState.$importQueue
            .map { !$0.isEmpty }
            .filter { $0 == true }
            .assign(to: \.hasImportedItem, on: self)
            .store(in: &disposeBag)
    }

    func onItemSelected(item: ArchiveItem) {
        selectedItem = item
        showInfoView = true
    }
}