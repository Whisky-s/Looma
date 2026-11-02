import AppKit
import Foundation
import SwiftUI

struct JSONCodeBlockView: View {
    let jsonString: String
    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1.0, green: 0.36, blue: 0.35)).frame(width: 8, height: 8)
                    Circle().fill(Color(red: 1.0, green: 0.75, blue: 0.2)).frame(width: 8, height: 8)
                    Circle().fill(Color(red: 0.18, green: 0.8, blue: 0.44)).frame(width: 8, height: 8)
                    Text("JSON")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.65, green: 0.70, blue: 0.78))
                        .padding(.leading, 4)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(jsonString, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        isCopied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        Text(isCopied ? "已复制" : "复制")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isCopied ? Color(red: 0.18, green: 0.8, blue: 0.44) : Color(red: 0.75, green: 0.8, blue: 0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(red: 0.13, green: 0.15, blue: 0.18))

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // High-contrast code content
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(jsonString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(red: 0.92, green: 0.95, blue: 0.98))
                    .lineSpacing(4)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 280)
            .background(Color(red: 0.09, green: 0.10, blue: 0.12))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.22, green: 0.25, blue: 0.30), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }
}
