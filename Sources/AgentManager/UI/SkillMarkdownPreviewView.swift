import AppKit
import SwiftUI

// MARK: - Markdown Block Model
enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String)
    case blockquote(text: String)
    case table(headers: [String], rows: [[String]])
    case listItem(number: Int?, text: String)
    case divider

    var id: String {
        switch self {
        case .heading(let l, let t): return "h-\(l)-\(t.prefix(20))"
        case .paragraph(let t): return "p-\(t.prefix(30))"
        case .codeBlock(let l, let c): return "code-\(l)-\(c.prefix(20))"
        case .blockquote(let t): return "quote-\(t.prefix(20))"
        case .table(let h, _): return "table-\(h.joined())"
        case .listItem(let n, let t): return "li-\(n ?? 0)-\(t.prefix(20))"
        case .divider: return "hr-\(UUID().uuidString)"
        }
    }
}

// MARK: - Skill Markdown Preview View
struct SkillMarkdownPreviewView: View {
    let fileURL: URL?
    let fallbackText: String?

    @State private var rawContent: String = ""
    @State private var frontmatter: [String: String] = [:]
    @State private var parsedBlocks: [MarkdownBlock] = []
    @State private var previewMode: Int = 0 // 0: 渲染预览, 1: 原始源码
    @State private var copiedNotice: Bool = false
    @State private var isLoading: Bool = true

    init(fileURL: URL?, fallbackText: String? = nil) {
        self.fileURL = fileURL
        self.fallbackText = fallbackText
    }

    var body: some View {
        VStack(spacing: 0) {
            // Preview Top Toolbar
            toolbarView

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Content Viewer
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.regular)
                    Text("正在解析 SKILL.md 文档...")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else if rawContent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 32))
                        .foregroundStyle(ManagerTheme.secondaryText.opacity(0.6))
                    Text("未找到有效的 SKILL.md 规范文件")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Text("该 Skill 目录下缺少 SKILL.md 说明文件")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ManagerTheme.canvasBg)
            } else {
                if previewMode == 0 {
                    renderedView
                } else {
                    rawSourceView
                }
            }
        }
        .onAppear {
            loadContent()
        }
        .onChange(of: fileURL) {
            loadContent()
        }
    }

    // MARK: - Toolbar
    private var toolbarView: some View {
        HStack(spacing: 10) {
            // Segmented Picker
            HStack(spacing: 2) {
                Button {
                    previewMode = 0
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 11))
                        Text("渲染预览")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(previewMode == 0 ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(previewMode == 0 ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                    .shadow(color: previewMode == 0 ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)

                Button {
                    previewMode = 1
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 11))
                        Text("原始源码")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(previewMode == 1 ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(previewMode == 1 ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                    .shadow(color: previewMode == 1 ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(2)
            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))

            // Stats Chip
            let lineCount = rawContent.components(separatedBy: .newlines).count
            let charCount = rawContent.count
            Text("\(lineCount) 行 · \(formatFileSize(charCount))")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(ManagerTheme.secondaryText)

            Spacer()

            // Open in External Editor (VS Code / Cursor / Default app)
            if let url = fileURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 11))
                        Text("外部打开")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ManagerTheme.primaryText)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
                .help("在系统默认编辑器中打开该 SKILL.md 文件")
            }

            // Copy Content Button
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(rawContent, forType: .string)
                copiedNotice = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copiedNotice = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copiedNotice ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10.5))
                    Text(copiedNotice ? "已复制" : "复制")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(copiedNotice ? ManagerTheme.mint : ManagerTheme.primaryText)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(copiedNotice ? ManagerTheme.mint.opacity(0.12) : ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    // MARK: - Rendered Markdown View
    private var renderedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Frontmatter Card (if available)
                if !frontmatter.isEmpty {
                    frontmatterHeaderCard
                }

                // Parsed Markdown Blocks
                ForEach(parsedBlocks) { block in
                    switch block {
                    case .heading(let level, let text):
                        headingBlockView(level: level, text: text)
                    case .paragraph(let text):
                        paragraphBlockView(text: text)
                    case .codeBlock(let language, let code):
                        codeBlockView(language: language, code: code)
                    case .blockquote(let text):
                        blockquoteView(text: text)
                    case .table(let headers, let rows):
                        tableBlockView(headers: headers, rows: rows)
                    case .listItem(let number, let text):
                        listItemView(number: number, text: text)
                    case .divider:
                        Divider().padding(.vertical, 6)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
    }

    // MARK: - Raw Source View
    private var rawSourceView: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(rawContent)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ManagerTheme.primaryText)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
        }
        .background(ManagerTheme.insetBg.opacity(0.5))
    }

    // MARK: - Frontmatter Card
    private var frontmatterHeaderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.electricBlue)
                Text("Skill 规范元数据 (YAML Frontmatter)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .tracking(0.6)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let name = frontmatter["name"] {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("标识:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .frame(width: 44, alignment: .leading)
                        Text(name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.electricBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let desc = frontmatter["description"] {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("描述:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .frame(width: 44, alignment: .leading)
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .lineSpacing(2)
                    }
                }

                ForEach(frontmatter.keys.sorted(), id: \.self) { key in
                    if key != "name" && key != "description" {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(key):")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .frame(width: 44, alignment: .leading)
                            Text(frontmatter[key] ?? "")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ManagerTheme.primaryText)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
    }

    // MARK: - Block Renderers
    private func headingBlockView(level: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch level {
            case 1:
                Text(text)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .padding(.top, 8)
                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(height: 1)
            case 2:
                Text(text)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .padding(.top, 6)
                Rectangle()
                    .fill(ManagerTheme.borderLine.opacity(0.7))
                    .frame(height: 0.8)
            case 3:
                Text(text)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .padding(.top, 4)
            default:
                Text(text)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .padding(.top, 2)
            }
        }
    }

    private func paragraphBlockView(text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(.system(size: 12.5))
            .foregroundStyle(ManagerTheme.primaryText)
            .lineSpacing(3.5)
            .textSelection(.enabled)
    }

    private func codeBlockView(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Code Header
            HStack {
                Text(language.isEmpty ? "CODE" : language.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(ManagerTheme.secondaryText)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text("复制代码")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(ManagerTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.04))

            // Code Content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .padding(10)
                    .textSelection(.enabled)
            }
        }
        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
    }

    private func blockquoteView(text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(ManagerTheme.electricBlue)
                .frame(width: 3)

            Text(LocalizedStringKey(text))
                .font(.system(size: 12))
                .foregroundStyle(ManagerTheme.secondaryText)
                .lineSpacing(2.5)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(ManagerTheme.electricBlue.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }

    private func listItemView(number: Int?, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let n = number {
                Text("\(n).")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .frame(width: 20, alignment: .trailing)
            } else {
                Circle()
                    .fill(ManagerTheme.electricBlue)
                    .frame(width: 5, height: 5)
                    .padding(.leading, 6)
            }

            Text(LocalizedStringKey(text))
                .font(.system(size: 12.5))
                .foregroundStyle(ManagerTheme.primaryText)
                .lineSpacing(2)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }

    private func tableBlockView(headers: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    ForEach(0..<headers.count, id: \.self) { i in
                        Text(headers[i])
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(minWidth: 100, alignment: .leading)
                    }
                }
                .background(ManagerTheme.insetBg)

                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(height: 1)

                // Table Rows
                ForEach(0..<rows.count, id: \.self) { rowIdx in
                    let row = rows[rowIdx]
                    HStack(spacing: 0) {
                        ForEach(0..<headers.count, id: \.self) { colIdx in
                            let cell = colIdx < row.count ? row[colIdx] : ""
                            Text(LocalizedStringKey(cell))
                                .font(.system(size: 11.5))
                                .foregroundStyle(ManagerTheme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .frame(minWidth: 100, alignment: .leading)
                        }
                    }
                    .background(rowIdx % 2 == 1 ? ManagerTheme.insetBg.opacity(0.3) : Color.white)

                    if rowIdx < rows.count - 1 {
                        Rectangle()
                            .fill(ManagerTheme.borderLine.opacity(0.5))
                            .frame(height: 0.6)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Parser & Loader
    private func loadContent() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            var loadedString: String? = nil

            if let url = fileURL {
                if let str = try? String(contentsOf: url, encoding: .utf8) {
                    loadedString = str
                } else {
                    // Try alternative filenames in directory
                    let parent = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
                    let alternatives = ["SKILL.md", "skill.md", "Skill.md", "SKILL.MD", "README.md", "readme.md"]
                    for alt in alternatives {
                        let target = parent.appendingPathComponent(alt)
                        if let str = try? String(contentsOf: target, encoding: .utf8) {
                            loadedString = str
                            break
                        }
                    }
                }
            }

            if loadedString == nil {
                loadedString = fallbackText
            }

            let content = loadedString ?? ""
            let (fm, blocks) = MarkdownDocumentParser.parse(content)

            await MainActor.run {
                self.rawContent = content
                self.frontmatter = fm
                self.parsedBlocks = blocks
                self.isLoading = false
            }
        }
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024.0
        return String(format: "%.1f KB", kb)
    }
}

// MARK: - Markdown Document Parser Helper
enum MarkdownDocumentParser {
    static func parse(_ raw: String) -> (frontmatter: [String: String], blocks: [MarkdownBlock]) {
        let lines = raw.components(separatedBy: .newlines)
        var fm: [String: String] = [:]
        var blocks: [MarkdownBlock] = []

        var inFrontmatter = false
        var bodyLines: [String] = []

        // Extract frontmatter
        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if idx == 0 && trimmed == "---" {
                inFrontmatter = true
                continue
            }
            if inFrontmatter {
                if trimmed == "---" {
                    inFrontmatter = false
                    continue
                }
                let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    let k = parts[0].trimmingCharacters(in: .whitespaces)
                    let v = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    fm[k] = v
                }
            } else {
                bodyLines.append(line)
            }
        }

        // Parse Body Lines into Blocks
        var lineIdx = 0
        while lineIdx < bodyLines.count {
            let line = bodyLines[lineIdx]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 1. Code Fence (```)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                lineIdx += 1
                while lineIdx < bodyLines.count {
                    let codeLine = bodyLines[lineIdx]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        lineIdx += 1
                        break
                    }
                    codeLines.append(codeLine)
                    lineIdx += 1
                }
                blocks.append(.codeBlock(language: lang, code: codeLines.joined(separator: "\n")))
                continue
            }

            // 2. Horizontal Divider
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.divider)
                lineIdx += 1
                continue
            }

            // 3. Headings
            if trimmed.hasPrefix("#") {
                var level = 0
                var rem = trimmed
                while rem.hasPrefix("#") {
                    level += 1
                    rem = String(rem.dropFirst())
                }
                let headingText = rem.trimmingCharacters(in: .whitespaces)
                if !headingText.isEmpty {
                    blocks.append(.heading(level: level, text: headingText))
                }
                lineIdx += 1
                continue
            }

            // 4. Blockquotes
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = [String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)]
                lineIdx += 1
                while lineIdx < bodyLines.count {
                    let nextTrimmed = bodyLines[lineIdx].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.hasPrefix(">") {
                        quoteLines.append(String(nextTrimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                        lineIdx += 1
                    } else {
                        break
                    }
                }
                blocks.append(.blockquote(text: quoteLines.joined(separator: " ")))
                continue
            }

            // 5. Table (starts with | and has | divider)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && lineIdx + 1 < bodyLines.count {
                let nextLine = bodyLines[lineIdx + 1].trimmingCharacters(in: .whitespaces)
                if nextLine.hasPrefix("|") && nextLine.contains("-") {
                    // Valid Table!
                    let headers = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    lineIdx += 2 // skip header and separator
                    var rows: [[String]] = []
                    while lineIdx < bodyLines.count {
                        let rowLine = bodyLines[lineIdx].trimmingCharacters(in: .whitespaces)
                        if rowLine.hasPrefix("|") && rowLine.hasSuffix("|") {
                            let cells = rowLine.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                            rows.append(cells)
                            lineIdx += 1
                        } else {
                            break
                        }
                    }
                    blocks.append(.table(headers: headers, rows: rows))
                    continue
                }
            }

            // 6. List items (- or * or 1.)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.listItem(number: nil, text: text))
                lineIdx += 1
                continue
            }

            let numPattern = #"^(\d+)\.\s+(.+)$"#
            if let regex = try? NSRegularExpression(pattern: numPattern) {
                let ns = trimmed as NSString
                if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                    let num = Int(ns.substring(with: match.range(at: 1)))
                    let text = ns.substring(with: match.range(at: 2))
                    blocks.append(.listItem(number: num, text: text))
                    lineIdx += 1
                    continue
                }
            }

            // 7. Regular Paragraph
            if !trimmed.isEmpty {
                var paraLines: [String] = [trimmed]
                lineIdx += 1
                while lineIdx < bodyLines.count {
                    let nextTrimmed = bodyLines[lineIdx].trimmingCharacters(in: .whitespaces)
                    if nextTrimmed.isEmpty || nextTrimmed.hasPrefix("#") || nextTrimmed.hasPrefix("```") || nextTrimmed.hasPrefix(">") || nextTrimmed.hasPrefix("- ") || nextTrimmed.hasPrefix("|") {
                        break
                    }
                    paraLines.append(nextTrimmed)
                    lineIdx += 1
                }
                blocks.append(.paragraph(text: paraLines.joined(separator: " ")))
                continue
            }

            lineIdx += 1
        }

        return (fm, blocks)
    }
}
