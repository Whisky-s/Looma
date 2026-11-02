import SwiftUI

struct ManagerDropdownOption: Identifiable {
    let id: String
    let title: String
    let detail: String?
}

/// Shared selector used for project scopes and recent Git repositories.
struct ManagerDropdown: View {
    let title: String
    let icon: String
    let accessibilityLabel: String
    let options: [ManagerDropdownOption]
    let selectedID: String?
    let onSelect: (String) -> Void
    @State private var isExpanded = false
    @State private var isHovered = false

    var body: some View {
        Button { isExpanded.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(ManagerTheme.electricBlue)
                Text(title).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(ManagerTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(isHovered || isExpanded ? ManagerTheme.activePillBg : Color.white, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(isExpanded ? ManagerTheme.electricBlue.opacity(0.35) : ManagerTheme.borderLine))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title)
        .help(title)
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(options) { option in
                        ManagerSelectionRow(title: option.title, detail: option.detail, selected: selectedID == option.id) {
                            onSelect(option.id)
                            isExpanded = false
                        }
                        .help(option.title + (option.detail.map { " · " + $0 } ?? ""))
                    }
                }
                .padding(8)
            }
            .frame(width: 360, height: min(CGFloat(options.count) * 58 + 16, 320))
            .background(ManagerTheme.canvasBg)
            .environment(\.colorScheme, .light)
        }
    }
}

struct ManagerSelectionRow: View {
    let title: String
    let detail: String?
    let selected: Bool
    var isEnabled: Bool = true
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(selected ? ManagerTheme.activePillBg : (isHovered ? ManagerTheme.insetBg : Color.white), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? ManagerTheme.electricBlue.opacity(0.35) : (isHovered ? ManagerTheme.borderLine : .clear)))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

