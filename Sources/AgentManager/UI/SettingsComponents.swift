import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(iconColor)
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)

                Spacer()
            }

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            content
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ManagerTheme.borderLine, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
}

struct SettingsSegmentedOption<Value: Hashable> {
    let value: Value
    let title: String
    let icon: String
    let badge: String?

    init(_ value: Value, title: String, icon: String, badge: String? = nil) {
        self.value = value
        self.title = title
        self.icon = icon
        self.badge = badge
    }
}

struct SettingsSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [SettingsSegmentedOption<Value>]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let isSelected = selection == option.value
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                            .font(.system(size: 12, weight: .semibold))

                        Text(option.title)
                            .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        if let badge = option.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ManagerTheme.electricBlue.opacity(isSelected ? 0.12 : 0.06), in: Capsule())
                        }
                    }
                    .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(isSelected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(isSelected ? ManagerTheme.electricBlue.opacity(0.25) : Color.clear, lineWidth: 1))
                    .shadow(color: isSelected ? Color.black.opacity(0.06) : .clear, radius: 4, y: 1.5)
                    .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}

struct SettingsChoiceCard: View {
    let isSelected: Bool
    let icon: String
    let title: String
    let badge: String?
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                            .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)

                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(ManagerTheme.electricBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                        }
                    }

                    Text(description)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isSelected ? ManagerTheme.electricBlue.opacity(0.06) : Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? ManagerTheme.electricBlue : ManagerTheme.borderLine, lineWidth: isSelected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
