import Photos
import SwiftUI

struct ResultView: View {
    let model: ResultModel

    enum Mode: String, CaseIterable, Identifiable {
        case original = "Gốc"
        case translated = "Bản dịch"
        case debug = "Debug"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .translated
    @State private var selected: TranslatedBlock?
    @State private var debugImage: UIImage?
    @State private var toast: String?

    private var displayed: UIImage {
        switch mode {
        case .original: model.original
        case .translated: model.translated
        case .debug: debugImage ?? model.original
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Chế độ xem", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if let notice = model.notice {
                Label(notice, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                Image(uiImage: displayed)
                    .resizable()
                    .scaledToFit()
                    .overlay { tapTargets }
                    .padding(.horizontal, 8)
                if mode == .debug { debugLegend }
            }
        }
        .navigationTitle("Kết quả")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    UIPasteboard.general.string = model.allTranslations
                    show("Đã sao chép toàn bộ bản dịch")
                } label: {
                    Label("Sao chép bản dịch", systemImage: "doc.on.doc")
                }
                .disabled(model.blocks.isEmpty)

                Spacer()

                ShareLink(item: Image(uiImage: displayed), preview: SharePreview("baoboiii", image: Image(uiImage: displayed))) {
                    Label("Chia sẻ", systemImage: "square.and.arrow.up")
                }

                Spacer()

                Button {
                    Task { await saveToPhotos() }
                } label: {
                    Label("Lưu vào Thư viện", systemImage: "square.and.arrow.down")
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $selected) { block in
            BlockDetailSheet(block: block)
                .presentationDetents([.medium, .large])
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .debug && debugImage == nil { debugImage = model.debugImage() }
        }
    }

    /// Invisible buttons over each translated block.
    private var tapTargets: some View {
        GeometryReader { geo in
            let scale = geo.size.width / max(model.original.size.width, 1)
            ForEach(model.blocks) { block in
                let f = block.frame
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: f.width * scale, height: f.height * scale)
                    .position(x: f.midX * scale, y: f.midY * scale)
                    .onTapGesture { selected = block }
            }
        }
        .allowsHitTesting(mode != .debug)
    }

    private var debugLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Khung đỏ: từng dòng OCR. Khung xanh lá: khối đã nhóm. Khung xanh dương: nhãn ngắn (nút/tab). Nhãn #số kèm mã ngôn ngữ; khối không có mã là bị bỏ qua.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(model.lines.count) dòng · \(model.textBlocks.count) khối · \(model.blocks.count) khối đã dịch")
                .font(.footnote.monospaced())
        }
        .padding()
    }

    private func show(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toast = nil }
        }
    }

    private func saveToPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            show(BaoboiiiError.cannotSaveImage.message)
            return
        }
        let image = displayed
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            show("Đã lưu ảnh vào Thư viện")
        } catch {
            show(BaoboiiiError.cannotSaveImage.message)
        }
    }
}

struct BlockDetailSheet: View {
    let block: TranslatedBlock
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Câu gốc (\(block.language.displayName))") {
                    Text(block.original).textSelection(.enabled)
                }
                Section("Bản dịch") {
                    Text(block.translation).textSelection(.enabled)
                }
                Section {
                    Button(copied ? "Đã sao chép" : "Sao chép bản dịch", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = block.translation
                        copied = true
                    }
                    Button("Sao chép câu gốc", systemImage: "character.textbox") {
                        UIPasteboard.general.string = block.original
                    }
                }
            }
            .navigationTitle("Khối #\(block.id)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
