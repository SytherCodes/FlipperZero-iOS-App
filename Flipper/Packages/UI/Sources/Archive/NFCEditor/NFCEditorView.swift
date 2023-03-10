import Core
import SwiftUI

struct NFCEditorView: View {
    @StateObject var viewModel: NFCEditorViewModel
    @Environment(\.dismiss) var dismiss

    @StateObject var hexKeyboardController: HexKeyboardController = .init()

    var body: some View {
        VStack(spacing: 0) {
            Header(
                title: "Edit Dump",
                description: viewModel.item.name.value,
                onCancel: { dismiss() },
                onSave: {
                    viewModel.save()
                    dismiss()
                }
            )

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        NFCCard(item: $viewModel.item)

                        HexEditor(
                            bytes: $viewModel.bytes,
                            width: proxy.size.width - 33
                        )
                    }
                    .padding(.top, 14)
                }
            }

            if !hexKeyboardController.isHidden {
                HexKeyboard(
                    onButton: { hexKeyboardController.onKey(.hex($0)) },
                    onBack: { hexKeyboardController.onKey(.back) },
                    onOK: { hexKeyboardController.onKey(.ok) }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .navigationBarHidden(true)
        .environmentObject(hexKeyboardController)
    }
}

extension NFCEditorView {
    struct NFCCard: View {
        @Binding var item: ArchiveItem

        var mifareType: String {
            guard let typeProperty = item.properties.first(
                where: { $0.key == "Mifare Classic type" }
            ) else {
                return "??"
            }
            return typeProperty.value
        }

        // FIXME: buggy padding

        var paddingLeading: Double {
            switch UIScreen.main.bounds.width {
            case 320: return 3
            case 414: return 24
            default: return 12
            }
        }

        var paddingTrailing: Double {
            switch UIScreen.main.bounds.width {
            case 320: return 4
            case 414: return 34
            default: return 17
            }
        }

        var body: some View {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        Text("MIFARE Classic \(mifareType)")
                            .font(.system(size: 12, weight: .heavy))

                        Image("NFCCardWaves")
                            .frame(width: 24, height: 24)
                    }
                    .padding(.top, 17)

                    Image("NFCCardInfo")
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 31)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("UID:")
                                .fontWeight(.bold)
                            Text(item["UID"] ?? "")
                                .fontWeight(.medium)
                        }

                        HStack(spacing: 23) {
                            HStack {
                                Text("ATQA:")
                                    .fontWeight(.bold)
                                Text(item["ATQA"] ?? "")
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("SAK:")
                                    .fontWeight(.bold)
                                Text(item["SAK"] ?? "")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .font(.system(size: 10))
                    .padding(.top, 32)
                    .padding(.bottom, 13)
                }
                .padding(.leading, paddingLeading)
                .padding(.trailing, paddingTrailing)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .background {
                Image("NFCCard")
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}

extension NFCEditorView {
    struct Header: View {
        let title: String
        let description: String?
        let onCancel: () -> Void
        let onSave: () -> Void

        var body: some View {
            HStack {
                Button {
                    onCancel()
                } label: {
                    Text("Close")
                        .foregroundColor(.primary)
                        .font(.system(size: 14, weight: .medium))
                }

                Spacer()

                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                    if let description = description {
                        Text(description)
                            .font(.system(size: 12, weight: .medium))
                    }
                }

                Spacer()

                Button {
                    onSave()
                } label: {
                    Text(" Save")
                        .foregroundColor(.primary)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .padding(.horizontal, 19)
            .padding(.top, 17)
            .padding(.bottom, 6)
        }
    }
}
