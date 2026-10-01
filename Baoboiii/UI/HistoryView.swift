import SwiftUI

struct HistoryView: View {
    @State private var entries: [HistoryStore.Entry] = []
    @State private var opened: ResultModel?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView("Chưa có lịch sử", systemImage: "clock",
                                           description: Text("Các lần dịch (trong app hoặc qua Phím tắt) sẽ hiện ở đây. App giữ \(HistoryStore.limit) lần gần nhất."))
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button {
                                opened = HistoryStore.load(entry)
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncThumbnail(url: entry.thumbnailURL)
                                        .frame(width: 54, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.date, format: .dateTime.day().month().hour().minute())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(entry.preview)
                                            .lineLimit(3)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet { HistoryStore.delete(entries[index]) }
                            entries = HistoryStore.entries()
                        }
                    }
                }
            }
            .navigationTitle("Lịch sử")
            .navigationDestination(item: $opened) { model in
                ResultView(model: model)
            }
            .onAppear { entries = HistoryStore.entries() }
            .refreshable { entries = HistoryStore.entries() }
        }
    }
}

private struct AsyncThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.15)
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            }
        }
        .task(id: url) {
            image = await Task.detached(priority: .utility) {
                guard let data = try? Data(contentsOf: url),
                      let cg = try? ImageLoader.cgImage(from: data, maxPixelSize: 300) else { return nil as UIImage? }
                return UIImage(cgImage: cg)
            }.value
        }
    }
}
