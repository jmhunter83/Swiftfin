//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// The loading view for the app when migrations are taking place
struct AppLoadingView: View {

    @State
    private var didFailMigration = false

    private var migrationFailureView: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(Color.red)
                .symbolRenderingMode(.monochrome)

            VStack(spacing: 12) {
                Text(L10n.migrationFailed)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(L10n.migrationFailedDescription)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 600)
            }

            VStack(spacing: 16) {
                Text(L10n.recoveryOptions)
                    .font(.headline)
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("• \(L10n.migrationRecoveryRetry)")
                    Text("• \(L10n.migrationRecoveryStorage)")
                    Text("• \(L10n.migrationRecoveryReset)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 600, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgePadding()
    }

    var body: some View {
        ZStack {
            Color.clear

            if didFailMigration {
                migrationFailureView
            } else {
                ProgressView()
            }
        }
        .onNotification(.didFailMigration) { _ in
            didFailMigration = true
        }
    }
}
