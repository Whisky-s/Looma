#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
swiftc -o /tmp/agent-manager-smoke Sources/AgentManager/Management/Core.swift Sources/AgentManager/Management/Content.swift Sources/AgentManager/Management/MCP.swift Sources/AgentManager/Management/History.swift Sources/AgentManager/Management/Presets.swift Sources/AgentManager/Management/Sync.swift Sources/AgentManager/Management/GitSkills.swift Tests/Smoke.swift Tests/Regressions.swift Tests/ContentVersions.swift -framework AppKit -framework CryptoKit
/tmp/agent-manager-smoke

swiftc -o /tmp/agent-manager-owner-rows Sources/AgentManager/Management/*.swift Sources/AgentManager/App/ViewModel.swift Tests/OwnerRows.swift -framework AppKit -framework CryptoKit -framework SwiftUI
/tmp/agent-manager-owner-rows
