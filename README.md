# baoboiii: Việt hoá toàn màn hình iPhone

Đang đọc RedNote (Xiaohongshu), Weibo, truyện Hàn… mà không hiểu? Gõ 2 lần vào lưng iPhone:
màn hình được chụp lại, chữ Trung, Hàn và Anh được dịch sang **tiếng Việt** rồi vẽ lại **đúng vị trí cũ**.
Ảnh đã dịch hiện ngay trên app bạn đang dùng.

- Nhận diện chữ bằng Apple Vision, chạy trên máy
- Dịch bằng **Apple** (miễn phí, chạy trên máy) hoặc **Gemini** (AI của Google, dịch tự nhiên hơn, cần API key)
- Cần iPhone chạy **iOS 26** trở lên

---

## 1. Tải file cài đặt `.ipa`

Cách dễ nhất:

1. Mở trang **Releases** của repo: <https://github.com/gigilee2310/Transbaoboi/releases/tag/latest>
2. Tải file **`baoboiii.ipa`** về máy tính Windows.

Cách khác: vào tab **Actions** → bấm vào lần chạy mới nhất có dấu ✅ xanh → kéo xuống mục **Artifacts** → tải **baoboiii-ipa**
(đây là file `.zip`, giải nén ra sẽ có `baoboiii.ipa`). Cách này cần đăng nhập GitHub.

## 2. Cài bằng Sideloadly (trên Windows)

1. Cài **iTunes** và **iCloud** bản tải từ **website Apple** (không dùng bản Microsoft Store):
   - iTunes: <https://www.apple.com/itunes/download/win64>
   - iCloud: <https://support.apple.com/HT204283>
2. Tải và cài **Sideloadly**: <https://sideloadly.io>
3. Cắm iPhone vào máy tính bằng cáp. Trên iPhone bấm **Tin cậy** (Trust) và nhập mật mã nếu được hỏi.
4. Mở Sideloadly:
   - Kéo file `baoboiii.ipa` vào cửa sổ Sideloadly.
   - Ô **Apple account**: nhập Apple ID của bạn (Apple ID miễn phí là được).
   - Bấm **Start**, nhập mật khẩu Apple ID khi được hỏi (mật khẩu chỉ gửi tới Apple).
     Nếu Apple ID bật xác thực 2 lớp, nhập mã gửi về iPhone.
5. Chờ đến khi Sideloadly báo **Done**.

> Apple ID miễn phí chỉ cài được **tối đa 3 app** tự ký cùng lúc.

## 3. Bật Developer Mode và tin cậy app

1. Trên iPhone: **Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển** (Developer Mode) → bật → iPhone khởi động lại → bấm **Bật**.
   (Nếu chưa thấy mục này, hãy cài app bằng Sideloadly một lần trước, mục sẽ xuất hiện.)
2. **Cài đặt → Cài đặt chung → VPN & Quản lý thiết bị** → chọn Apple ID của bạn → **Tin cậy**.
3. Mở app **baoboiii**.

## 4. App hết hạn sau 7 ngày

Với Apple ID miễn phí, app tự ký chỉ chạy được **7 ngày**. Hết hạn thì app không mở được nữa, nhưng **dữ liệu vẫn còn**. Cách cài lại:

- Cắm iPhone, mở Sideloadly, kéo lại file `baoboiii.ipa` và bấm **Start**, giống lần đầu.
- Mẹo: trong Sideloadly bật **Automatic refresh**. Khi máy tính và iPhone dùng chung Wi-Fi, Sideloadly sẽ tự ký lại trước khi hết hạn.
- Muốn bản mới nhất thì tải lại file `.ipa` ở bước 1.

## 5. Chuẩn bị bộ dịch

Vào tab **Cài đặt** trong app:

- **Bộ dịch Apple** (mặc định): bấm **Gói ngôn ngữ Apple**, rồi bấm **Tải** cho Trung (giản thể), Trung (phồn thể), Hàn, Anh.
  Chỉ cần tải một lần. Nếu thiếu gói, Phím tắt sẽ báo lỗi.
- **Bộ dịch Gemini** (tùy chọn, xem mục 7).

## 6. Tạo Phím tắt + Chạm vào mặt sau

**Tạo Phím tắt** trong app **Phím tắt** (Shortcuts):

1. Bấm **+** để tạo phím tắt mới.
2. Thêm tác vụ **Chụp ảnh màn hình** (Take Screenshot).
3. Thêm tác vụ **Dịch màn hình** của baoboiii. Ô "Ảnh" phải tự nối với "Ảnh màn hình".
   Nếu không thấy baoboiii, hãy mở app baoboiii một lần rồi thử lại.
4. Thêm tác vụ **Xem nhanh** (Quick Look).
5. Đặt tên, ví dụ **Việt hoá**.

**Gán vào lưng máy:** **Cài đặt → Trợ năng → Cảm ứng → Chạm vào mặt sau → Chạm hai lần** → chọn phím tắt **Việt hoá**.

Giờ mở app Trung hoặc Hàn bất kỳ và gõ 2 lần vào lưng iPhone. Lần đầu iOS có thể hỏi quyền, hãy chọn **Luôn cho phép**.
Muốn xem câu gốc hay sao chép bản dịch, mở baoboiii → tab **Lịch sử**.

## 7. Lấy API key Gemini (tùy chọn)

Gemini dịch tự nhiên hơn hẳn: xưng hô anh/em, văn phong mạng xã hội, tên riêng Hán-Việt.

1. Vào <https://aistudio.google.com/apikey> và đăng nhập bằng tài khoản Google.
2. Bấm **Create API key** và sao chép key.
3. Trong baoboiii: **Cài đặt → Gemini** → dán key → **Lưu API key** → **Thử kết nối Gemini**.
4. Đổi **Bộ dịch** sang **Gemini**.

Lưu ý:

- Key miễn phí có giới hạn số lần dùng mỗi phút và mỗi ngày. Vượt giới hạn thì app tự chuyển sang bộ dịch Apple, nếu đã tải gói ngôn ngữ.
- Ảnh màn hình được gửi lên Google để dịch đúng ngữ cảnh. Với key miễn phí, Google có thể dùng dữ liệu này để cải thiện dịch vụ.
  Nếu không muốn, tắt **Gửi kèm ảnh** để chỉ gửi chữ.
- Model mặc định là `gemini-3.8-flash`. Muốn nhanh và rẻ hơn thì chọn `gemini-3.5-flash-lite`.

## 8. Khi dịch sai vị trí: chế độ Debug

Mở ảnh trong app (tab **Dịch** hoặc **Lịch sử**) → chọn **Debug**:

- **Khung đỏ**: từng dòng chữ mà Vision nhận diện được.
- **Khung xanh lá**: các dòng đã được gộp thành một khối (đoạn văn, bong bóng chat).
- **Khung xanh dương**: nhãn ngắn như nút hoặc tab.
- `#số zh-Hans/ko/en`: số thứ tự khối và ngôn ngữ nhận diện được. Khối không có mã ngôn ngữ là bị bỏ qua.

Lưu ảnh Debug và gửi cho người phát triển để chỉnh lại cách nhóm khối.

---

## Dành cho người phát triển

```
project.yml                  XcodeGen (không commit .xcodeproj)
.github/workflows/build.yml  CI: xcodegen → unit test → build Release chưa ký → .ipa → artifact + release "latest"
Baoboiii/
  App/        BaoboiiiApp, RootView (4 tab)
  Pipeline/   OCRService (Vision) → LayoutGrouper → LanguageDetector → Translator
              (AppleTranslator, GeminiTranslator, TranslationCache) → Inpainter → TextRenderer
              ScreenAnalyzer / ScreenTranslator điều phối, DebugRenderer vẽ khung
  Intents/    TranslateScreenIntent + AppShortcutsProvider
  UI/         Home, Result, History, Settings, LanguagePack, Guide
  Support/    AppSettings, Keychain, HistoryStore, BaoboiiiError (thông báo tiếng Việt)
BaoboiiiTests/  LayoutGrouper, LanguageDetector, Gemini parser, cache, inpainter, layout
```

**Apple Translation trong App Intent:** từ iOS 26 có `TranslationSession(installedSource:target:)`, dùng được ngoài SwiftUI nên chạy được trong intent nền.
Hàm này chỉ dùng được gói ngôn ngữ đã tải sẵn. Việc tải gói cần giao diện (`.translationTask` + `prepareTranslation()`), nên được đặt ở màn hình *Gói ngôn ngữ Apple*.
Nếu thiếu gói, intent báo lỗi tiếng Việt; nếu có key Gemini thì tự chuyển sang Gemini.

## Kế hoạch sau

- Share Extension (dịch từ menu Chia sẻ)
- Chế độ truyện: chữ dọc tiếng Nhật/Trung, phát hiện bong bóng thoại (speech bubble)
- Inpainting bằng model CoreML thay cho tô màu trung vị
- Chế độ tự động: ReplayKit Broadcast + Picture-in-Picture
- Safari Web Extension
