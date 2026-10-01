import SwiftUI
import Translation

/// Downloads Apple translation packs. Downloading needs UI (`.translationTask`), which is why it lives
/// here and not in the App Intent: the intent can only use packs that are already installed.
struct LanguagePackView: View {
    @State private var statuses: [SourceLanguage: LanguageAvailability.Status] = [:]
    @State private var configuration: TranslationSession.Configuration?
    @State private var downloading: SourceLanguage?

    var body: some View {
        List {
            Section {
                ForEach(SourceLanguage.allCases) { lang in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(lang.displayName) → Việt")
                            Text(statusText(statuses[lang]))
                                .font(.caption)
                                .foregroundStyle(statuses[lang] == .installed ? .green : .secondary)
                        }
                        Spacer()
                        if downloading == lang {
                            ProgressView()
                        } else if statuses[lang] == .supported {
                            Button("Tải") { download(lang) }
                                .buttonStyle(.bordered)
                        } else if statuses[lang] == .installed {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
            } footer: {
                Text("Bấm \"Tải\" rồi xác nhận trong hộp thoại của Apple. Gói ngôn ngữ chỉ cần tải một lần; sau đó bản dịch Apple chạy hoàn toàn trên máy, kể cả khi dùng qua Phím tắt. Bạn cũng có thể quản lý trong Cài đặt iPhone → Ứng dụng → Dịch thuật → Ngôn ngữ đã tải về.")
            }
        }
        .navigationTitle("Gói ngôn ngữ Apple")
        .task { await refresh() }
        .translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
            } catch {
                // User cancelled or download failed; the status refresh shows the result.
            }
            await MainActor.run { downloading = nil }
            await refresh()
        }
    }

    private func download(_ lang: SourceLanguage) {
        downloading = lang
        if configuration?.source == lang.localeLanguage {
            configuration?.invalidate()  // same pair again: re-run the task
        } else {
            configuration = TranslationSession.Configuration(source: lang.localeLanguage, target: AppleTranslator.target)
        }
    }

    @MainActor
    private func refresh() async {
        for lang in SourceLanguage.allCases {
            statuses[lang] = await AppleTranslator.status(for: lang)
        }
    }

    private func statusText(_ status: LanguageAvailability.Status?) -> String {
        switch status {
        case .installed: "Đã tải"
        case .supported: "Chưa tải"
        case .unsupported: "Không hỗ trợ"
        case nil: "Đang kiểm tra…"
        default: "Không rõ"
        }
    }
}
