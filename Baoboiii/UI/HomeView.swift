import PhotosUI
import SwiftUI

struct HomeView: View {
    @AppStorage(AppSettings.Key.engine) private var engine = TranslationEngine.apple.rawValue
    @State private var pickerItem: PhotosPickerItem?
    @State private var result: ResultModel?
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var missingPacks: [SourceLanguage] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Việt hoá ảnh chụp màn hình")
                            .font(.title2.bold())
                        Text("Chọn một ảnh chụp màn hình có chữ Trung, Hàn hoặc Anh. baoboiii sẽ nhận diện chữ, dịch sang tiếng Việt và vẽ lại đúng vị trí.")
                            .foregroundStyle(.secondary)
                    }

                    PhotosPicker(selection: $pickerItem, matching: .screenshots) {
                        Label("Chọn ảnh chụp màn hình", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isWorking)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Chọn ảnh bất kỳ trong Thư viện", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isWorking)

                    if isWorking {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Đang nhận diện và dịch…")
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }

                    statusCard
                }
                .padding()
            }
            .navigationTitle("baoboiii")
            .navigationDestination(item: $result) { model in
                ResultView(model: model)
            }
            .task(id: engine) { await refreshPacks() }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await translate(item) }
        }
    }

    @ViewBuilder private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Bộ dịch: \((TranslationEngine(rawValue: engine) ?? .apple).displayName)", systemImage: "globe")
            if engine == TranslationEngine.apple.rawValue && !missingPacks.isEmpty {
                Label("Chưa tải gói ngôn ngữ: \(missingPacks.map(\.displayName).joined(separator: ", ")). Vào Cài đặt → Gói ngôn ngữ Apple.",
                      systemImage: "arrow.down.circle")
                    .foregroundStyle(.orange)
            }
            Label("Muốn dịch ngay trên app khác? Xem tab Hướng dẫn để gán vào Chạm vào mặt sau.", systemImage: "hand.tap")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    private func refreshPacks() async {
        var missing: [SourceLanguage] = []
        for lang in SourceLanguage.allCases {
            if await AppleTranslator.status(for: lang) != .installed { missing.append(lang) }
        }
        missingPacks = missing
    }

    private func translate(_ item: PhotosPickerItem) async {
        isWorking = true
        errorMessage = nil
        defer {
            isWorking = false
            pickerItem = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw BaoboiiiError.cannotReadImage }
            DiagnosticsLog.log("▶︎ Dịch trong app")
            let outcome = try await ScreenTranslator().run(imageData: data)
            let model = ResultModel(outcome: outcome)
            if !model.blocks.isEmpty { HistoryStore.save(model) }
            result = model
        } catch {
            errorMessage = (error as? BaoboiiiError)?.message ?? error.localizedDescription
            DiagnosticsLog.log("❌ \(errorMessage ?? "")")
        }
    }
}
