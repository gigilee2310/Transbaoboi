import AppIntents
import UniformTypeIdentifiers
import UIKit

/// "Dịch màn hình": takes a screenshot from Shortcuts, returns the Vietnamese PNG.
/// Runs in the background (no app UI) so Quick Look can show the result on top of the current app.
struct TranslateScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Dịch màn hình"
    static let description = IntentDescription(
        "Nhận diện chữ Trung, Hàn, Anh trong ảnh chụp màn hình, dịch sang tiếng Việt và vẽ lại đúng vị trí. Dùng cùng tác vụ Chụp ảnh màn hình và Xem nhanh.",
        categoryName: "Dịch"
    )
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Ảnh", description: "Ảnh chụp màn hình cần dịch",
               supportedContentTypes: [.image], inputConnectionBehavior: .connectToPreviousIntentResult)
    var image: IntentFile

    static var parameterSummary: some ParameterSummary {
        Summary("Dịch \(\.$image) sang tiếng Việt")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let clock = Stopwatch()
        let state = await MainActor.run { UIApplication.shared.applicationState }
        DiagnosticsLog.log("▶︎ Phím tắt bắt đầu (app đang \(state == .active ? "mở" : "chạy ngầm"))")
        do {
            let file = try await translate()
            DiagnosticsLog.log("✅ Xong sau \(clock.ms) ms")
            DiagnosticsLog.flush()
            return .result(value: file)
        } catch {
            DiagnosticsLog.log("❌ Lỗi sau \(clock.ms) ms: \((error as? BaoboiiiError)?.message ?? String(describing: error))")
            DiagnosticsLog.flush()
            throw error
        }
    }

    private func translate() async throws -> IntentFile {
        let data = image.data
        DiagnosticsLog.log("Nhận ảnh: \(image.filename), \(data.count / 1024) KB")
        // Smaller working image in the background: faster OCR, less memory, still sharp enough for CJK.
        let outcome = try await ScreenTranslator.background.run(imageData: data, maxPixelSize: 2200)
        guard !outcome.blocks.isEmpty else {
            throw outcome.analysis.languages.isEmpty ? BaoboiiiError.nothingToTranslate : BaoboiiiError.badResponse
        }

        let clock = Stopwatch()
        let jpeg: Data? = autoreleasepool { outcome.translated.jpegData(compressionQuality: 0.92) }
        guard let jpeg else { throw BaoboiiiError.cannotReadImage }
        DiagnosticsLog.log("Xuất ảnh \(jpeg.count / 1024) KB (\(clock.ms) ms)")

        let saveClock = Stopwatch()
        HistoryStore.save(ResultModel(outcome: outcome))
        DiagnosticsLog.log("Lưu lịch sử (\(saveClock.ms) ms)")

        return IntentFile(data: jpeg, filename: "baoboiii-\(Int(Date().timeIntervalSince1970)).jpg", type: .jpeg)
    }
}

struct BaoboiiiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateScreenIntent(),
            phrases: [
                "Dịch màn hình bằng \(.applicationName)",
                "Việt hoá bằng \(.applicationName)",
            ],
            shortTitle: "Dịch màn hình",
            systemImageName: "character.bubble"
        )
    }
}
