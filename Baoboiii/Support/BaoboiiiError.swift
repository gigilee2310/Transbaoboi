import Foundation

/// All user-facing errors, with Vietnamese messages (shown in the app and in Shortcuts).
enum BaoboiiiError: LocalizedError, CustomLocalizedStringResourceConvertible {
    case cannotReadImage
    case noTextFound
    case nothingToTranslate
    case languagePackMissing([SourceLanguage])
    case appleTranslationFailed(String)
    case missingAPIKey
    case gemini(status: Int, message: String)
    case network(String)
    case timeout
    case badResponse
    case cannotSaveImage

    var message: String {
        switch self {
        case .cannotReadImage:
            return "Không đọc được ảnh. Hãy thử lại với ảnh chụp màn hình khác."
        case .noTextFound:
            return "Không tìm thấy chữ nào trong ảnh."
        case .nothingToTranslate:
            return "Không có chữ Trung, Hàn hay Anh nào cần dịch trong ảnh."
        case .languagePackMissing(let langs):
            let names = langs.map(\.displayName).joined(separator: ", ")
            return "Chưa tải gói ngôn ngữ \(names) → Việt. Mở app baoboiii → Cài đặt → Gói ngôn ngữ Apple để tải (chỉ cần làm một lần)."
        case .appleTranslationFailed(let detail):
            return "Bộ dịch Apple gặp lỗi: \(detail)"
        case .missingAPIKey:
            return "Chưa nhập API key Gemini. Mở app baoboiii → Cài đặt để nhập, hoặc chuyển sang bộ dịch Apple."
        case .gemini(let status, let message):
            switch status {
            case 400: return "Gemini từ chối yêu cầu (400): \(message)"
            case 401, 403: return "API key Gemini không hợp lệ hoặc chưa được cấp quyền. Kiểm tra lại key trong Cài đặt."
            case 404: return "Không tìm thấy model Gemini. Kiểm tra tên model trong Cài đặt."
            case 429: return "Đã dùng hết lượt miễn phí của Gemini, hãy thử lại sau ít phút hoặc chuyển sang bộ dịch Apple."
            default: return "Gemini gặp lỗi (\(status)): \(message)"
            }
        case .network(let detail):
            return "Không kết nối được mạng: \(detail)"
        case .timeout:
            return "Dịch quá lâu nên đã dừng. Hãy thử lại."
        case .badResponse:
            return "Bản dịch trả về không đúng định dạng. Hãy thử lại."
        case .cannotSaveImage:
            return "Không lưu được ảnh. Hãy cho phép baoboiii thêm ảnh vào Thư viện trong Cài đặt iPhone."
        }
    }

    var errorDescription: String? { message }

    var localizedStringResource: LocalizedStringResource { "\(message)" }
}
