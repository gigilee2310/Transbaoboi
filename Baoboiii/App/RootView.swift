import PhotosUI
import SwiftUI

struct RootView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var debugImage: UIImage?
    @State private var analysis: ScreenAnalysis?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Chọn ảnh từ Thư viện", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if isWorking { ProgressView("Đang nhận diện chữ…") }
                    if let errorMessage { Text(errorMessage).foregroundStyle(.red) }

                    if let debugImage {
                        Image(uiImage: debugImage).resizable().scaledToFit()
                    }
                    if let analysis {
                        ForEach(analysis.blocks) { block in
                            HStack(alignment: .top) {
                                Text("#\(block.id)").monospaced().foregroundStyle(.secondary)
                                Text(block.text)
                                Spacer()
                                Text(analysis.languages[block.id]?.displayName ?? "bỏ qua")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("baoboiii · Debug")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await analyze(item) }
        }
    }

    private func analyze(_ item: PhotosPickerItem) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw BaoboiiiError.cannotReadImage }
            let image = try ImageLoader.cgImage(from: data)
            let result = try await ScreenAnalyzer().analyze(image, preferred: nil)
            analysis = result
            let tags = result.languages.mapValues(\.rawValue)
            debugImage = DebugRenderer.render(image: image, lines: result.lines, blocks: result.blocks, tags: tags)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
