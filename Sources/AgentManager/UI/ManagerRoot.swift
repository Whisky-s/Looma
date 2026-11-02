import AppKit
import Foundation
import SwiftUI

public struct ManagerRoot: View {
    @StateObject private var vm = AgentManagerViewModel.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                SidebarView(vm: vm)
                    .frame(width: 244)

                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(width: 1)

                MainContentView(vm: vm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if vm.detailPresentationMode == .sidebar, let selectedItem = vm.selectedDisplayItem, vm.page < 2 {
                    Rectangle()
                        .fill(ManagerTheme.borderLine)
                        .frame(width: 1)

                    InspectorView(vm: vm, item: selectedItem, rows: vm.inspectorTargetRows)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: vm.selectedItemName)
        }
        .toastNotification(vm: vm, isRoot: true)
        .foregroundStyle(ManagerTheme.primaryText)
        .background(ManagerTheme.canvasBg)
        .ignoresSafeArea()
        .sheet(isPresented: $vm.showNewMCPSheet) {
            MCPEditorSheet(vm: vm, initialMCP: vm.editingMCPItem)
                .toastNotification(vm: vm)
        }
        .sheet(isPresented: $vm.showGitImportSheet) {
            GitSkillSheet(vm: vm)
                .toastNotification(vm: vm)
        }
        .sheet(isPresented: $vm.showAdoptionSheet) {
            AdoptionSheet(vm: vm, requestedName: vm.adoptionRequest,
                          candidates: vm.adoptionCandidates(name: vm.adoptionRequest))
                .toastNotification(vm: vm)
        }
        .sheet(item: $vm.selectedModalItem) { item in
            ItemDetailSheet(vm: vm, item: item, rows: vm.inspectorTargetRows)
                .toastNotification(vm: vm)
        }
        // The palette uses fixed light surfaces; native fields and sheets must match.
        .preferredColorScheme(.light)
    }
}
