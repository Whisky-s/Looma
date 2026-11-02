import AppKit
import Foundation
import SwiftUI

struct ToastBanner: View {
    let toast: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? Color.red : ManagerTheme.mint)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)

                if let detail = toast.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(toast.isError ? Color.red.opacity(0.85) : ManagerTheme.secondaryText)
                        .lineLimit(toast.isError ? 4 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 520, alignment: .leading)
                        .textSelection(.enabled)
                        .help(detail)
                }
            }

            if let undo = toast.undoAction {
                Button {
                    undo()
                    onDismiss()
                } label: {
                    Text("撤销")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.electricBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(ManagerTheme.electricBlue.opacity(0.12), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(toast.isError ? Color.red.opacity(0.25) : ManagerTheme.borderLine, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.15), radius: 18, y: 6)
    }
}

struct ToastNotificationOverlay: ViewModifier {
    @ObservedObject var vm: AgentManagerViewModel
    var isRoot: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                let shouldShow = isRoot ? (vm.activeToast != nil && !vm.hasPresentedSheet) : (vm.activeToast != nil)
                if shouldShow, let toast = vm.activeToast {
                    ToastBanner(toast: toast, onDismiss: { vm.dismissToast() })
                        .padding(.bottom, isRoot ? 26 : 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(9999)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: vm.activeToast)
    }
}

extension View {
    func toastNotification(vm: AgentManagerViewModel, isRoot: Bool = false) -> some View {
        self.modifier(ToastNotificationOverlay(vm: vm, isRoot: isRoot))
    }
}
