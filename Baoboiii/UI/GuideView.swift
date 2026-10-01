import SwiftUI

struct GuideView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Sau khi cài xong, chỉ cần **gõ 2 lần vào mặt lưng iPhone** khi đang xem app Trung/Hàn: màn hình được chụp lại, dịch sang tiếng Việt và hiện ngay lên trên app bạn đang dùng.")
                }

                Section("Bước 0 · Chuẩn bị") {
                    GuideStep(number: 0, text: "Mở baoboiii ít nhất một lần sau khi cài (để iPhone nhận ra hành động \"Dịch màn hình\").")
                    GuideStep(number: 0, text: "Nếu dùng bộ dịch Apple: vào Cài đặt → Gói ngôn ngữ Apple và tải Trung, Hàn, Anh.")
                }

                Section("Bước 1 · Tạo Phím tắt") {
                    GuideStep(number: 1, text: "Mở app **Phím tắt** (Shortcuts) → bấm **+** để tạo phím tắt mới.")
                    GuideStep(number: 2, text: "Bấm **Thêm tác vụ**, tìm **Chụp ảnh màn hình** (Take Screenshot) và thêm vào.")
                    GuideStep(number: 3, text: "Tìm **baoboiii** hoặc **Dịch màn hình**, thêm tác vụ **Dịch màn hình**. Ô \"Ảnh\" phải tự nối với \"Ảnh màn hình\" ở trên.")
                    GuideStep(number: 4, text: "Tìm **Xem nhanh** (Quick Look) và thêm vào cuối.")
                    GuideStep(number: 5, text: "Đặt tên phím tắt, ví dụ **Việt hoá**, rồi bấm **Xong**.")
                    Button("Mở app Phím tắt", systemImage: "arrow.up.forward.app") {
                        if let url = URL(string: "shortcuts://") { openURL(url) }
                    }
                }

                Section("Bước 2 · Gán vào Chạm vào mặt sau") {
                    GuideStep(number: 1, text: "Mở **Cài đặt** iPhone → **Trợ năng** → **Cảm ứng**.")
                    GuideStep(number: 2, text: "Kéo xuống cuối, chọn **Chạm vào mặt sau**.")
                    GuideStep(number: 3, text: "Chọn **Chạm hai lần** (hoặc Chạm ba lần), kéo xuống mục Phím tắt và chọn **Việt hoá**.")
                    GuideStep(number: 4, text: "Xong! Mở RedNote, Weibo, truyện Hàn… rồi gõ 2 lần vào lưng máy.")
                }

                Section("Mẹo") {
                    Text("• Lần đầu chạy, iOS có thể hỏi quyền cho phím tắt, hãy chọn **Luôn cho phép**.")
                    Text("• Trong màn hình Xem nhanh, bấm nút chia sẻ để lưu hoặc gửi ảnh đã dịch.")
                    Text("• Muốn xem lại câu gốc hay sao chép bản dịch: mở baoboiii → tab **Lịch sử**.")
                    Text("• Dịch chưa đúng vị trí? Mở ảnh trong baoboiii, chọn chế độ **Debug**, chụp màn hình gửi cho người phát triển.")
                }
            }
            .navigationTitle("Hướng dẫn")
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if number > 0 {
                Text("\(number)")
                    .font(.caption.bold())
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.accentColor.opacity(0.2)))
            } else {
                Image(systemName: "checkmark.circle").foregroundStyle(.tint)
            }
            Text(text)
        }
    }
}
