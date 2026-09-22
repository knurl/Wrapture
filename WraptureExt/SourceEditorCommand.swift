import Foundation
#if canImport(XcodeKit)
import XcodeKit
#endif

class SourceEditorCommand: NSObject {
#if canImport(XcodeKit)
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        rewrapComments(in: invocation.buffer)
        completionHandler(nil)
    }
#endif

    func rewrapCommentLines(
        _ sourceLines: [String],
        selectedLines: Range<Int>? = nil,
        insertionLine: Int? = nil,
        maximumLineLength: Int = WraptureSettings.defaultWrapLength
    ) -> [String] {
        let lines = NSMutableArray(array: sourceLines)
        let maximumLineLength = WraptureSettings.clampedWrapLength(maximumLineLength)

        if let insertionLine, let block = commentBlock(containing: insertionLine, in: lines) {
            replace(block, in: lines, maximumLineLength: maximumLineLength)
            return lines.compactMap { $0 as? String }
        }

        let requestedRange = selectedLines ?? 0..<lines.count
        let lowerBound = max(0, min(requestedRange.lowerBound, lines.count))
        let upperBound = max(lowerBound, min(requestedRange.upperBound, lines.count))
        let targetRange = lowerBound..<upperBound
        rewrapCommentBlocks(in: targetRange, lines: lines, maximumLineLength: maximumLineLength)
        return lines.compactMap { $0 as? String }
    }

#if canImport(XcodeKit)
    private func rewrapComments(in buffer: XCSourceTextBuffer) {
        let selectedRange = selectedLineRange(in: buffer)
        let lineCount = buffer.lines.count
        guard lineCount > 0 else { return }
        let maximumLineLength = WraptureSettings.wrapLength

        if selectedRange.isInsertionPoint,
           let block = commentBlock(containing: selectedRange.start, in: buffer.lines) {
            replace(block, in: buffer.lines, maximumLineLength: maximumLineLength)
            return
        }

        let targetRange = selectedRange.boundsClamped(toLineCount: lineCount)
        rewrapCommentBlocks(in: targetRange, lines: buffer.lines, maximumLineLength: maximumLineLength)
    }

    private func selectedLineRange(in buffer: XCSourceTextBuffer) -> SelectedLineRange {
        guard let selection = buffer.selections.firstObject as? XCSourceTextRange else {
            return SelectedLineRange(start: 0, endExclusive: buffer.lines.count, isInsertionPoint: false)
        }

        let startLine = min(selection.start.line, selection.end.line)
        let endLine = max(selection.start.line, selection.end.line)
        let isInsertionPoint = selection.start.line == selection.end.line && selection.start.column == selection.end.column
        let endExclusive = isInsertionPoint || selection.end.column > 0 ? endLine + 1 : endLine

        return SelectedLineRange(start: startLine, endExclusive: endExclusive, isInsertionPoint: isInsertionPoint)
    }
#endif

    private func rewrapCommentBlocks(in range: Range<Int>, lines: NSMutableArray, maximumLineLength: Int) {
        var lineIndex = range.lowerBound
        var upperBound = min(range.upperBound, lines.count)

        while lineIndex < upperBound, lineIndex < lines.count {
            guard let block = commentBlock(startingAt: lineIndex, upperBound: upperBound, in: lines) else {
                lineIndex += 1
                continue
            }

            let originalLineCount = block.range.count
            let replacement = block.rewrappedLines(maximumLineLength: maximumLineLength)
            lines.replaceObjects(in: NSRange(location: block.range.lowerBound, length: originalLineCount), withObjectsFrom: replacement)
            upperBound += replacement.count - originalLineCount
            lineIndex = block.range.lowerBound + replacement.count
        }
    }

    private func replace(_ block: CommentBlock, in lines: NSMutableArray, maximumLineLength: Int) {
        lines.replaceObjects(
            in: NSRange(location: block.range.lowerBound, length: block.range.count),
            withObjectsFrom: block.rewrappedLines(maximumLineLength: maximumLineLength)
        )
    }

    private func commentBlock(containing line: Int, in lines: NSMutableArray) -> CommentBlock? {
        guard line >= 0, line < lines.count else { return nil }

        if let lineComment = parseLineComment(lines[line] as? String ?? "") {
            var start = line
            while start > 0,
                  let comment = parseLineComment(lines[start - 1] as? String ?? ""),
                  comment.signature == lineComment.signature {
                start -= 1
            }

            var end = line + 1
            while end < lines.count,
                  let comment = parseLineComment(lines[end] as? String ?? ""),
                  comment.signature == lineComment.signature {
                end += 1
            }

            return lineCommentBlock(in: start..<end, lines: lines)
        }

        return blockComment(containing: line, in: lines)
    }

    private func commentBlock(startingAt line: Int, upperBound: Int, in lines: NSMutableArray) -> CommentBlock? {
        if let lineComment = parseLineComment(lines[line] as? String ?? "") {
            var end = line + 1
            while end < upperBound,
                  end < lines.count,
                  let comment = parseLineComment(lines[end] as? String ?? ""),
                  comment.signature == lineComment.signature {
                end += 1
            }

            return lineCommentBlock(in: line..<end, lines: lines)
        }

        guard let blockStart = parseBlockCommentStart(lines[line] as? String ?? "") else {
            return nil
        }

        let blockEnd = blockCommentEnd(startingAt: line, upperBound: upperBound, in: lines)
        return blockComment(in: line..<blockEnd, start: blockStart, lines: lines)
    }

    private func lineCommentBlock(in range: Range<Int>, lines: NSMutableArray) -> CommentBlock? {
        let comments = range.compactMap { parseLineComment(lines[$0] as? String ?? "") }
        guard let firstComment = comments.first else { return nil }

        let endings = replacementLineEndings(for: range, lines: lines)

        return CommentBlock(
            range: range,
            indentation: firstComment.indentation,
            style: .line(marker: firstComment.marker),
            paragraphs: paragraphs(from: comments.map(\.content)),
            lineEnding: endings.lineEnding,
            finalLineEnding: endings.finalLineEnding
        )
    }

    private func blockComment(containing line: Int, in lines: NSMutableArray) -> CommentBlock? {
        var start = line
        while start >= 0 {
            if let blockStart = parseBlockCommentStart(lines[start] as? String ?? "") {
                let end = blockCommentEnd(startingAt: start, upperBound: lines.count, in: lines)
                guard line < end else { return nil }
                return blockComment(in: start..<end, start: blockStart, lines: lines)
            }

            if containsBlockCommentEnd(lines[start] as? String ?? "") && start != line {
                return nil
            }

            start -= 1
        }

        return nil
    }

    private func blockComment(in range: Range<Int>, start: BlockCommentStart, lines: NSMutableArray) -> CommentBlock? {
        var contents = range.map {
            blockCommentContent(
                from: lines[$0] as? String ?? "",
                linePosition: linePosition(for: $0, in: range),
                indentation: start.indentation
            )
        }

        if range.count > 1 {
            if contents.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                contents.removeFirst()
            }

            if contents.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                contents.removeLast()
            }
        }

        let endings = replacementLineEndings(for: range, lines: lines)

        return CommentBlock(
            range: range,
            indentation: start.indentation,
            style: .block(opener: start.opener, putsFirstTextOnOpeningLine: start.hasOpeningLineContent),
            paragraphs: paragraphs(from: contents),
            lineEnding: endings.lineEnding,
            finalLineEnding: endings.finalLineEnding
        )
    }

    private func blockCommentEnd(startingAt start: Int, upperBound: Int, in lines: NSMutableArray) -> Int {
        var line = start
        while line < upperBound, line < lines.count {
            if containsBlockCommentEnd(lines[line] as? String ?? "") {
                return line + 1
            }

            line += 1
        }

        return min(upperBound, lines.count)
    }

    private func replacementLineEndings(for range: Range<Int>, lines: NSMutableArray) -> (lineEnding: String, finalLineEnding: String) {
        let endings = range.map { splitLineEnding(from: lines[$0] as? String ?? "").lineEnding }
        let lineEnding = endings.first { !$0.isEmpty } ?? ""
        let finalLineEnding = endings.last ?? lineEnding
        return (lineEnding, finalLineEnding)
    }

    private func linePosition(for line: Int, in range: Range<Int>) -> BlockLinePosition {
        if range.count == 1 {
            return .single
        }

        if line == range.lowerBound {
            return .first
        }

        if line == range.upperBound - 1 {
            return .last
        }

        return .middle
    }

    private func paragraphs(from contents: [String]) -> [CommentParagraph] {
        var paragraphs: [CommentParagraph] = []
        var currentLines: [String] = []

        func flushLines() {
            guard !currentLines.isEmpty else { return }

            let text = currentLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
            paragraphs.append(.text(
                text,
                firstLineIndent: leadingWhitespaceCount(in: currentLines[0]),
                continuationIndent: continuationIndent(for: currentLines)
            ))
            currentLines.removeAll()
        }

        for content in contents {
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushLines()
                paragraphs.append(.blank)
            } else if listContinuationIndent(in: content) != nil {
                flushLines()
                currentLines.append(content)
            } else {
                currentLines.append(content)
            }
        }

        flushLines()
        return paragraphs
    }

    private func continuationIndent(for lines: [String]) -> Int {
        if let listIndent = listContinuationIndent(in: lines[0]) {
            return listIndent
        }

        guard lines.count > 1 else {
            return leadingWhitespaceCount(in: lines[0])
        }

        return leadingWhitespaceCount(in: lines[1])
    }

    private func listContinuationIndent(in text: String) -> Int? {
        let characters = Array(text)
        var index = 0

        while index < characters.count, characters[index] == " " || characters[index] == "\t" {
            index += 1
        }

        guard index < characters.count else { return nil }

        if ["-", "*", "+"].contains(characters[index]) {
            let markerEnd = index + 1
            guard markerEnd < characters.count, characters[markerEnd].isWhitespace else { return nil }
            return markerEnd + 1
        }

        let digitStart = index
        while index < characters.count, characters[index].isNumber {
            index += 1
        }

        guard index > digitStart,
              index < characters.count,
              characters[index] == "." || characters[index] == ")" else {
            return nil
        }

        let markerEnd = index + 1
        guard markerEnd < characters.count, characters[markerEnd].isWhitespace else { return nil }
        return markerEnd + 1
    }

    private func leadingWhitespaceCount(in text: String) -> Int {
        text.prefix { $0 == " " || $0 == "\t" }.count
    }

    private func parseLineComment(_ line: String) -> LineComment? {
        let components = splitLineEnding(from: line)
        let text = components.text
        let indentation = String(text.prefix { $0 == " " || $0 == "\t" })
        let remaining = text.dropFirst(indentation.count)

        let marker: String
        if remaining.hasPrefix("///") {
            marker = "///"
        } else if remaining.hasPrefix("//!") {
            marker = "//!"
        } else if remaining.hasPrefix("//") {
            marker = "//"
        } else {
            return nil
        }

        var content = String(remaining.dropFirst(marker.count))
        if content.hasPrefix(" ") {
            content.removeFirst()
        }

        return LineComment(indentation: indentation, marker: marker, content: content)
    }

    private func parseBlockCommentStart(_ line: String) -> BlockCommentStart? {
        let components = splitLineEnding(from: line)
        let text = components.text
        let indentation = String(text.prefix { $0 == " " || $0 == "\t" })
        let remaining = text.dropFirst(indentation.count)

        let opener: String
        if remaining.hasPrefix("/**") {
            opener = "/**"
        } else if remaining.hasPrefix("/*!") {
            opener = "/*!"
        } else if remaining.hasPrefix("/*") {
            opener = "/*"
        } else {
            return nil
        }

        var openingLineContent = String(remaining.dropFirst(opener.count))
        removeBlockCloser(from: &openingLineContent)
        removeBlockContentSeparator(from: &openingLineContent)

        return BlockCommentStart(
            indentation: indentation,
            opener: opener,
            hasOpeningLineContent: !openingLineContent.trimmingCharacters(in: .whitespaces).isEmpty
        )
    }

    private func containsBlockCommentEnd(_ line: String) -> Bool {
        splitLineEnding(from: line).text.contains("*/")
    }

    private func blockCommentContent(
        from line: String,
        linePosition: BlockLinePosition,
        indentation: String
    ) -> String {
        var text = splitLineEnding(from: line).text
        if text.hasPrefix(indentation) {
            text.removeFirst(indentation.count)
        }

        switch linePosition {
        case .single:
            removeBlockOpener(from: &text)
            removeBlockCloser(from: &text)
            removeBlockContentSeparator(from: &text)
        case .first:
            removeBlockOpener(from: &text)
            removeBlockContentSeparator(from: &text)
        case .middle:
            removeBlockLinePrefix(from: &text)
        case .last:
            removeBlockCloser(from: &text)
            removeBlockLinePrefix(from: &text)
        }

        return text.trimmingTrailingWhitespace()
    }

    private func removeBlockOpener(from text: inout String) {
        if text.hasPrefix("/**") || text.hasPrefix("/*!") {
            text.removeFirst(3)
        } else if text.hasPrefix("/*") {
            text.removeFirst(2)
        }
    }

    private func removeBlockCloser(from text: inout String) {
        guard let range = text.range(of: "*/", options: .backwards) else { return }
        text.removeSubrange(range.lowerBound..<text.endIndex)
    }

    private func removeLeadingBlockAsterisk(from text: inout String) {
        guard text.hasPrefix("*") else { return }
        text.removeFirst()
        if text.hasPrefix(" ") {
            text.removeFirst()
        }
    }

    private func removeBlockLinePrefix(from text: inout String) {
        if text.hasPrefix(" *") {
            text.removeFirst()
            removeLeadingBlockAsterisk(from: &text)
        } else if text.hasPrefix("*") {
            removeLeadingBlockAsterisk(from: &text)
        } else {
            removeBlockContentSeparator(from: &text)
        }
    }

    private func removeBlockContentSeparator(from text: inout String) {
        if text.hasPrefix(" ") {
            text.removeFirst()
        }
    }

    private func splitLineEnding(from line: String) -> (text: String, lineEnding: String) {
        if line.hasSuffix("\r\n") {
            return (String(line.dropLast(2)), "\r\n")
        }

        if line.hasSuffix("\n") || line.hasSuffix("\r") {
            return (String(line.dropLast()), String(line.suffix(1)))
        }

        return (line, "")
    }
}

#if canImport(XcodeKit)
extension SourceEditorCommand: XCSourceEditorCommand {}
#endif

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var result = self
        while result.last == " " || result.last == "\t" {
            result.removeLast()
        }
        return result
    }
}

struct CommentBlock {
    let range: Range<Int>
    let indentation: String
    let style: CommentStyle
    let paragraphs: [CommentParagraph]
    let lineEnding: String
    let finalLineEnding: String

    func rewrappedLines(maximumLineLength: Int) -> [String] {
        let lines: [String]

        switch style {
        case .line(let marker):
            lines = rewrappedLineCommentLines(marker: marker, maximumLineLength: maximumLineLength)
        case .block(let opener, let putsFirstTextOnOpeningLine):
            lines = rewrappedBlockCommentLines(
                opener: opener,
                putsFirstTextOnOpeningLine: putsFirstTextOnOpeningLine,
                maximumLineLength: maximumLineLength
            )
        }

        return lines.enumerated().map { index, line in
            line + (index == lines.count - 1 ? finalLineEnding : lineEnding)
        }
    }

    private func rewrappedLineCommentLines(marker: String, maximumLineLength: Int) -> [String] {
        let prefix = indentation + marker
        let contentWidth = maximumLineLength - prefix.count - 1

        return paragraphs.flatMap { paragraph -> [String] in
            switch paragraph {
            case .blank:
                return [prefix]
            case .text(let text, let firstLineIndent, let continuationIndent):
                return wrap(text, width: contentWidth, firstLineIndent: firstLineIndent, continuationIndent: continuationIndent).map { prefix + " " + $0 }
            }
        }
    }

    private func rewrappedBlockCommentLines(
        opener: String,
        putsFirstTextOnOpeningLine: Bool,
        maximumLineLength: Int
    ) -> [String] {
        let contentPrefix = indentation + " *"
        let contentWidth = maximumLineLength - contentPrefix.count - 1
        var lines = [indentation + opener]
        var remainingParagraphs = paragraphs[...]

        if putsFirstTextOnOpeningLine,
           case .text(let text, let firstLineIndent, let continuationIndent) = remainingParagraphs.first {
            let openingPrefix = indentation + opener
            let openingWidth = maximumLineLength - openingPrefix.count - 1
            let wrapped = wrap(
                text,
                width: openingWidth,
                firstLineIndent: firstLineIndent,
                continuationIndent: continuationIndent
            )

            if let firstLine = wrapped.first {
                lines[0] = openingPrefix + " " + firstLine
                lines.append(contentsOf: wrapped.dropFirst().map { contentPrefix + " " + $0 })
            }

            remainingParagraphs.removeFirst()
        }

        for paragraph in remainingParagraphs {
            switch paragraph {
            case .blank:
                lines.append(contentPrefix)
            case .text(let text, let firstLineIndent, let continuationIndent):
                lines.append(contentsOf: wrap(text, width: contentWidth, firstLineIndent: firstLineIndent, continuationIndent: continuationIndent).map { contentPrefix + " " + $0 })
            }
        }

        lines.append(indentation + " */")
        return lines
    }

    private func wrap(_ text: String, width: Int, firstLineIndent: Int, continuationIndent: Int) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return [""] }

        let firstLinePrefix = String(repeating: " ", count: firstLineIndent)
        let continuationPrefix = String(repeating: " ", count: continuationIndent)
        let firstLineWidth = max(width - firstLineIndent, 20)
        let continuationWidth = max(width - continuationIndent, 20)
        var lines: [String] = []
        var currentLine = ""
        var currentWidth = firstLineWidth

        for word in words {
            if currentLine.isEmpty {
                currentLine = word
            } else if currentLine.count + 1 + word.count <= currentWidth {
                currentLine += " " + word
            } else {
                lines.append(currentLine)
                currentLine = word
                currentWidth = continuationWidth
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.enumerated().map { index, line in
            (index == 0 ? firstLinePrefix : continuationPrefix) + line
        }
    }
}

enum CommentStyle {
    case line(marker: String)
    case block(opener: String, putsFirstTextOnOpeningLine: Bool)
}

enum CommentParagraph {
    case text(String, firstLineIndent: Int, continuationIndent: Int)
    case blank
}

private enum BlockLinePosition {
    case single
    case first
    case middle
    case last
}

private struct LineComment {
    let indentation: String
    let marker: String
    let content: String

    var signature: String {
        indentation + marker
    }
}

private struct BlockCommentStart {
    let indentation: String
    let opener: String
    let hasOpeningLineContent: Bool
}

private struct SelectedLineRange {
    let start: Int
    let endExclusive: Int
    let isInsertionPoint: Bool

    func boundsClamped(toLineCount lineCount: Int) -> Range<Int> {
        let lowerBound = max(0, min(start, lineCount))
        let upperBound = max(lowerBound, min(endExclusive, lineCount))
        return lowerBound..<upperBound
    }
}
