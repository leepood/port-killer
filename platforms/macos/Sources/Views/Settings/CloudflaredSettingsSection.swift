/// CloudflaredSettingsSection - Cloudflare tunnel preferences
///
/// Displays cloudflared settings including:
/// - Transport protocol selection (HTTP/2 or QUIC)

import SwiftUI
import Defaults

struct CloudflaredSettingsSection: View {
    @Default(.cloudflaredProtocol) private var protocolSelection

    var body: some View {
        SettingsGroup("Cloudflare Tunnels", icon: "cloud.fill") {
            SettingsRowContainer {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tunnel protocol")
                            .fontWeight(.medium)
                        Text("Choose how cloudflared connects to Cloudflare (applies to new tunnels)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $protocolSelection) {
                        ForEach(CloudflaredProtocol.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
    }
}
