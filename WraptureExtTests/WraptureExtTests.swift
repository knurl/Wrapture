import Testing
import Foundation

struct WraptureExtTests {
    private let formatter = SourceEditorCommand()
    private let maximumLineLength = 100

    @Test func wrapsIndentedLineComment() {
        let input = [
            "    // Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega alpha beta gamma.\n"
        ]

        let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

        #expect(output == [
            "    // Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma\n",
            "    // tau upsilon phi chi psi omega alpha beta gamma.\n"
        ])
        expectLinesFit(output)
    }

    @Test func preservesParagraphBreaksInLineComments() {
        let input = [
            "// First paragraph has enough words to reflow into a clean comment line without disturbing the blank separator.\n",
            "//\n",
            "// Second paragraph follows the intentional gap and should remain visually separated after wrapping.\n"
        ]

        let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

        #expect(output.contains("//\n"))
        #expect(output.first == "// First paragraph has enough words to reflow into a clean comment line without disturbing the blank\n")
        #expect(output.last == "// Second paragraph follows the intentional gap and should remain visually separated after wrapping.\n")
        expectLinesFit(output)
    }

    @Test func keepsDocumentationCommentContinuationIndentation() {
        let input = [
            "/// - parameter value: This parameter has a deliberately long explanation that continues across multiple words\n",
            "///   so wrapping should keep continuation indentation aligned with the original list item and its follow-up text.\n"
        ]

        let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

        #expect(output.first?.hasPrefix("/// - parameter value:") == true)
        #expect(output.dropFirst().allSatisfy { $0.hasPrefix("///   ") })
        expectLinesFit(output)
    }

    @Test func secondLineIndentControlsLineCommentContinuations() {
        let markers = ["//", "///", "//!"]

        for marker in markers {
            let input = [
                "\(marker) First line starts flush with the comment marker and introduces a thought that will wrap\n",
                "\(marker)     second line is indented and establishes the hanging indentation for every wrapped continuation that follows.\n"
            ]

            let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

            #expect(output.count >= 3)
            #expect(output.first?.hasPrefix("\(marker) First line") == true)
            #expect(output.dropFirst().allSatisfy { $0.hasPrefix("\(marker)     ") })
            expectLinesFit(output)
        }
    }

    @Test func secondLineIndentControlsBlockCommentContinuations() {
        let openers = ["/*", "/**", "/*!"]

        for opener in openers {
            let input = [
                "\(opener)\n",
                " * First line starts flush with the block comment text and introduces a thought that will wrap\n",
                " *     second line is indented and establishes the hanging indentation for every wrapped continuation that follows.\n",
                " */\n"
            ]

            let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)
            let contentLines = output.dropFirst().dropLast()

            #expect(output.first == "\(opener)\n")
            #expect(output.last == " */\n")
            #expect(contentLines.count >= 3)
            #expect(contentLines.first?.hasPrefix(" * First line") == true)
            #expect(contentLines.dropFirst().allSatisfy { $0.hasPrefix(" *     ") })
            expectLinesFit(output)
        }
    }

    @Test func keepsOpeningLineTextOnPlainBlockComment() {
        let input = [
            "            /* 2) A document already exists with the same UUID. We will start with an attempt to\n",
            "             *    keep the same document, but update the PDF fork\n",
            "             *     with our new PDF, leaving the metadata and content forks in place, unchanged.\n",
            "             */\n"
        ]

        let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

        #expect(output.first?.hasPrefix("            /* 2) A document already exists") == true)
        #expect(output.dropFirst().dropLast().allSatisfy { $0.hasPrefix("             *    ") })
        #expect(!output.contains("            /*\n"))
        expectLinesFit(output)
    }

    @Test func keepsEmptyBlockCommentOpenerOnItsOwnLine() {
        let input = [
            "    /**\n",
            "     * A block comment opener with no same-line text should stay on its own line while preserving indentation and the documentation opener.\n",
            "     */\n"
        ]

        let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

        #expect(output.first == "    /**\n")
        #expect(output.last == "     */\n")
        #expect(output.dropFirst().dropLast().allSatisfy { $0.hasPrefix("     * ") })
        expectLinesFit(output)
    }

    @Test func insertionPointRewrapsContainingCommentBlock() {
        let input = [
            "let value = 1\n",
            "// Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega alpha beta gamma.\n",
            "// Follow-on text stays part of the same contiguous comment block and is included when the insertion point sits inside it.\n",
            "let next = 2\n"
        ]

        let output = formatter.rewrapCommentLines(input, insertionLine: 2, maximumLineLength: maximumLineLength)

        #expect(output.first == "let value = 1\n")
        #expect(output.last == "let next = 2\n")
        #expect(output[1].hasPrefix("// Alpha beta"))
        #expect(output.dropFirst().dropLast().allSatisfy { $0.hasPrefix("//") })
        expectLinesFit(output)
    }

    @Test func selectionDoesNotExpandToAdjacentCommentBlocks() {
        let selectedComment = "// Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega alpha beta gamma.\n"
        let unselectedComment = "// This neighboring comment is intentionally outside the selected range and should remain exactly as it was.\n"
        let input = [
            selectedComment,
            unselectedComment
        ]

        let output = formatter.rewrapCommentLines(input, selectedLines: 0..<1, maximumLineLength: maximumLineLength)

        #expect(output.count == 3)
        #expect(output[0] == "// Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau\n")
        #expect(output[1] == "// upsilon phi chi psi omega alpha beta gamma.\n")
        #expect(output[2] == unselectedComment)
        expectLinesFit(output[0...1])
    }

    @Test func preservesCarriageReturnLineEndings() {
        let input = [
            "// Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega alpha beta gamma.\r\n"
        ]

        let output = formatter.rewrapCommentLines(input, maximumLineLength: maximumLineLength)

        #expect(output.allSatisfy { $0.hasSuffix("\r\n") })
        expectLinesFit(output)
    }

    private func expectLinesFit<S: Sequence>(_ lines: S) where S.Element == String {
        for line in lines {
            #expect(line.trimmingCharacters(in: .newlines).count <= 100)
        }
    }
}
