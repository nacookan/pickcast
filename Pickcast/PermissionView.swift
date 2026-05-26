import SwiftUI

struct PermissionView: View {
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.rectangle.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Screen Recording Permission Required")
                    .font(.title2.weight(.semibold))
                Text("Pickcast needs Screen Recording access to mirror windows from other apps.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 380)
            }

            VStack(spacing: 10) {
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                    )
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Check Again", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding(48)
        .frame(minWidth: 500, minHeight: 400)
    }
}
