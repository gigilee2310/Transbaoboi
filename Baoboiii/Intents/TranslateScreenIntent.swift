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
        let outcome = try await ScreenTranslator().run(imageData: image.data)
        guard !outcome.blocks.isEmpty else {
            throw outcome.analysis.languages.isEmpty ? BaoboiiiError.nothingToTranslate : BaoboiiiError.badResponse
        }

        let png: Data? = autoreleasepool {
            guard let cg = outcome.translated.cgImage else { return nil }
            return ImageLoader.pngData(cg)
        }
        guard let png else { throw BaoboiiiError.cannotReadImage }

        HistoryStore.save(ResultModel(outcome: outcome))

        let file = IntentFile(data: png, filename: "baoboiii-\(Int(Date().timeIntervalSince1970)).png", type: .png)
        return .result(value: file)
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
