import SwiftUI
import ScreenCaptureKit

struct WindowPickerView: View {
    let onSelect: (SCWindow) -> Void
    @State private var windows: [SCWindow] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [SCWindow] {
        guard !searchText.isEmpty else { return windows }
        let q = searchText.lowercased()
        return windows.filter {
            ($0.title ?? "").lowercased().contains(q) ||
            ($0.owningApplication?.applicationName ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 640, minHeight: 460)
        .task { await loadWindows() }
    }

    private var header: some View {
        HStack {
            Text("Select a Window")
                .font(.headline)
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $searchText).textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if isLoading {
                Spacer()
                ProgressView("Loading windows…")
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                Text("No windows found").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 220))],
                        spacing: 12
                    ) {
                        ForEach(filtered, id: \.windowID) { window in
                            WindowTile(window: window) { onSelect(window) }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func loadWindows() async {
        let myPID = ProcessInfo.processInfo.processIdentifier
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            windows = content.windows
                .filter { w in
                    w.isOnScreen &&
                    w.windowLayer == 0 &&
                    w.owningApplication != nil &&
                    w.owningApplication!.processID != myPID &&
                    !(w.title?.isEmpty ?? true)
                }
                .sorted {
                    ($0.owningApplication?.applicationName ?? "") <
                    ($1.owningApplication?.applicationName ?? "")
                }
        } catch {}
        isLoading = false
    }
}

private struct WindowTile: View {
    let window: SCWindow
    let onSelect: () -> Void
    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                    if let thumb = thumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ProgressView().scaleEffect(0.6)
                    }
                }
                .frame(height: 110)

                VStack(spacing: 2) {
                    Text(window.title ?? "Untitled")
                        .lineLimit(1)
                        .font(.caption.weight(.medium))
                    Text(window.owningApplication?.applicationName ?? "")
                        .lineLimit(1)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovering
                        ? Color(nsColor: .selectedControlColor)
                        : Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let wid = window.windowID
        let image = await Task.detached(priority: .utility) {
            CGWindowListCreateImage(.null, .optionIncludingWindow, wid,
                                    [.boundsIgnoreFraming, .bestResolution])
        }.value
        if let cg = image {
            thumbnail = NSImage(cgImage: cg, size: .zero)
        }
    }
}
