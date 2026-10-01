import SwiftUI

struct DiagnosticsView: View {
    @State private var text = ""
    @State private var copied = false

    var body: some View {
        ScrollView {
            Text(text.isEmpty ? "Chưa có nhật ký. Hãy thử dịch một lần (trong app hoặc bằng Phím tắt) rồi quay lại đây." : text)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .defaultScrollAnchor(.bottom)
        .navigationTitle("Nhật ký chạy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(copied ? "Đã sao chép" : "Sao chép", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = text
                    copied = true
                }
                Spacer()
                Button("Làm mới", systemImage: "arrow.clockwise") { reload() }
                Spacer()
                Button("Xoá", systemImage: "trash", role: .destructive) {
                    DiagnosticsLog.clear()
                    reload()
                }
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        let all = DiagnosticsLog.read()
        // Show the most recent part; the full log is still available via "Sao chép".
        let lines = all.split(separator: "\n")
        text = lines.suffix(120).joined(separator: "\n")
        copied = false
    }
}
