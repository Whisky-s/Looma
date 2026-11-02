import AppKit
import Foundation
import SwiftUI

enum ManagerTheme {
    static let canvasBg = Color(red: 0.957, green: 0.965, blue: 0.976)
    static let sidebarBg = Color(red: 0.925, green: 0.933, blue: 0.945)
    static let cardBg = Color.white
    static let insetBg = Color(red: 0.973, green: 0.980, blue: 0.988)
    static let borderLine = Color(red: 0.886, green: 0.906, blue: 0.929)

    static let primaryText = Color(red: 0.06, green: 0.09, blue: 0.16)
    static let secondaryText = Color(red: 0.40, green: 0.44, blue: 0.52)

    static let electricBlue = Color(red: 0.145, green: 0.388, blue: 0.922)
    static let skyGradient = LinearGradient(
        colors: [Color(red: 0.01, green: 0.52, blue: 0.78), Color(red: 0.22, green: 0.74, blue: 0.97)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let activePillBg = Color(red: 0.878, green: 0.933, blue: 0.992)
    static let activePillText = Color(red: 0.008, green: 0.400, blue: 0.933)

    static let indigo = Color(red: 0.38, green: 0.35, blue: 0.95)
    static let mint = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let amber = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let enableGreen = Color(red: 0.035, green: 0.52, blue: 0.37)
    static let stopOrange = Color(red: 0.62, green: 0.32, blue: 0.04)
}
