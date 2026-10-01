import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Key.engine) private var engine = TranslationEngine.apple.rawValue
    @AppStorage(AppSettings.Key.source) private var source = AppSettings.autoSource
    @AppStorage(AppSettings.Key.geminiModel) private var geminiModel = AppSettings.defaultGeminiModel
    @AppStorage(AppSettings.Key.geminiSendImage) private var geminiSendImage = true

    @State private var keyInput = ""
    @State private var savedKey: String? = Keychain.geminiAPIKey
    @State private var testMessage: String?
    @State private var isTesting = false
    @State private var cacheCount = 0
    @State private var confirmClearHistory = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Bộ dịch", selection: $engine) {
                        ForEach(TranslationEngine.allCases) { Text($0.displayName).tag($0.rawValue) }
                    }
                    Picker("Ngôn ngữ nguồn", selection: $source) {
                        Text("Tự động").tag(AppSettings.autoSource)
                        ForEach(SourceLanguage.allCases) { Text($0.displayName).tag($0.rawValue) }
                    }
                } header: {
                    Text("Dịch")
                } footer: {
                    Text("Apple dịch ngay trên máy, miễn phí, không gửi dữ liệu đi đâu. Gemini dịch tự nhiên hơn (xưng hô, văn phong) nhưng cần API key và gửi ảnh lên Google. Nếu bộ dịch đang chọn gặp lỗi, app sẽ tự thử bộ còn lại.")
                }

                Section("Apple") {
                    NavigationLink {
                        LanguagePackView()
                    } label: {
                        Label("Gói ngôn ngữ Apple", systemImage: "arrow.down.circle")
                    }
                }

                geminiSection

                Section("Dữ liệu") {
                    Button("Xoá bộ nhớ đệm bản dịch (\(cacheCount))", systemImage: "trash") {
                        Task {
                            await TranslationCache.shared.clear()
                            cacheCount = 0
                        }
                    }
                    Button("Xoá toàn bộ lịch sử", systemImage: "trash", role: .destructive) {
                        confirmClearHistory = true
                    }
                }

                Section {
                    LabeledContent("Phiên bản", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                }
            }
            .navigationTitle("Cài đặt")
            .task { cacheCount = await TranslationCache.shared.count }
            .confirmationDialog("Xoá toàn bộ lịch sử dịch?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Xoá", role: .destructive) { HistoryStore.deleteAll() }
            }
        }
    }

    @ViewBuilder private var geminiSection: some View {
        Section {
            if let savedKey {
                LabeledContent("API key", value: "••••" + String(savedKey.suffix(4)))
                Button("Xoá API key", role: .destructive) {
                    Keychain.geminiAPIKey = nil
                    self.savedKey = nil
                }
            } else {
                SecureField("Dán API key vào đây", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Lưu API key") {
                    let key = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    Keychain.geminiAPIKey = key
                    savedKey = Keychain.geminiAPIKey
                    keyInput = ""
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            HStack {
                TextField("Model", text: $geminiModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                Menu {
                    ForEach(AppSettings.suggestedGeminiModels, id: \.self) { name in
                        Button(name) { geminiModel = name }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                }
            }

            Toggle("Gửi kèm ảnh để dịch sát ngữ cảnh", isOn: $geminiSendImage)

            Button {
                Task { await testGemini() }
            } label: {
                HStack {
                    Text("Thử kết nối Gemini")
                    if isTesting { Spacer(); ProgressView() }
                }
            }
            .disabled(savedKey == nil || isTesting)

            if let testMessage {
                Text(testMessage).font(.footnote).foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                Label("Lấy API key miễn phí tại Google AI Studio", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("Gemini")
        } footer: {
            Text("API key được lưu an toàn trong Keychain của iPhone. Với key miễn phí, Google có thể dùng dữ liệu gửi lên để cải thiện dịch vụ; tắt \"Gửi kèm ảnh\" nếu màn hình có nội dung riêng tư.")
        }
    }

    private func testGemini() async {
        guard let key = savedKey else { return }
        isTesting = true
        defer { isTesting = false }
        let translator = GeminiTranslator(apiKey: key, model: geminiModel, sendImage: false)
        do {
            let result = try await translator.translate(
                [TranslationItem(id: 1, text: "你好，很高兴认识你！", language: .chineseSimplified),
                 TranslationItem(id: 2, text: "오늘 날씨 정말 좋네요", language: .korean)],
                context: nil)
            testMessage = "✅ Hoạt động tốt:\n" + [1, 2].compactMap { result[$0] }.joined(separator: "\n")
        } catch {
            testMessage = "❌ " + ((error as? BaoboiiiError)?.message ?? error.localizedDescription)
        }
    }
}
