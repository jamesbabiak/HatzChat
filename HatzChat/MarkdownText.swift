import SwiftUI
import AppKit

struct MarkdownText: View {
    let text: String

    var body: some View {
        AutoSizingLinkText(text: text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }
}

// MARK: - SwiftUI wrapper

private struct AutoSizingLinkText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> AutoSizingTextContainerView {
        let v = AutoSizingTextContainerView()
        v.setText(text)
        return v
    }

    func updateNSView(_ nsView: AutoSizingTextContainerView, context: Context) {
        nsView.setText(text)
    }
}

// MARK: - Auto-sizing container (fixes "blank bubbles")

private final class AutoSizingTextContainerView: NSView {

    private let textView: LinkOnlyTextView = {
        let tv = LinkOnlyTextView(frame: .zero)
        tv.translatesAutoresizingMaskIntoConstraints = false

        tv.drawsBackground = false
        tv.isEditable = false
        tv.isSelectable = false            // <- no selection
        tv.isRichText = true
        tv.importsGraphics = false
        tv.allowsUndo = false

        // Appearance (match normal SwiftUI Text pretty closely)
        tv.textColor = .labelColor
        tv.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)

        // Wrapping (no horizontal scrolling)
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.heightTracksTextView = false

        return tv
    }()

    private var lastWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ newText: String) {
        if textView.string == newText { return }

        // Build attributed string with link attributes (no reliance on automatic detection)
        let attr = Linkifier.makeAttributedString(
            from: newText,
            baseFont: textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            baseColor: textView.textColor ?? .labelColor
        )

        textView.textStorage?.setAttributedString(attr)

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let w = bounds.width
        if abs(w - lastWidth) > 0.5 {
            lastWidth = w
            if let tc = textView.textContainer {
                tc.containerSize = NSSize(width: w, height: .greatestFiniteMagnitude)
                tc.widthTracksTextView = true
            }
            if let tc = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: tc)
            }
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: NSSize {
        guard let lm = textView.layoutManager, let tc = textView.textContainer else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 18)
        }

        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let height = ceil(used.height) + 2
        return NSSize(width: NSView.noIntrinsicMetric, height: max(18, height))
    }
}

// MARK: - NSTextView that opens links on click + provides Copy menu

private final class LinkOnlyTextView: NSTextView {

    // Right-click menu (reliable even when SwiftUI contextMenu isn't)
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copyWholeMessage(_:)), keyEquivalent: "")
        return menu
    }

    @objc private func copyWholeMessage(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self.string, forType: .string)
    }

    // Link click handling
    override func mouseDown(with event: NSEvent) {
        guard let lm = layoutManager, let tc = textContainer else { return }

        // Convert to text container coords (important!)
        var point = convert(event.locationInWindow, from: nil)
        let origin = textContainerOrigin
        point.x -= origin.x
        point.y -= origin.y

        lm.ensureLayout(for: tc)

        // Find character index at click
        let glyphIndex = lm.glyphIndex(for: point, in: tc)
        let charIndex = lm.characterIndexForGlyph(at: glyphIndex)

        if charIndex < (string as NSString).length,
           let link = textStorage?.attribute(.link, at: charIndex, effectiveRange: nil) {

            if let url = link as? URL {
                NSWorkspace.shared.open(url)
                return
            } else if let str = link as? String, let url = URL(string: str) {
                NSWorkspace.shared.open(url)
                return
            }
        }

        // Do nothing (prevents selection)
    }

    override func mouseDragged(with event: NSEvent) {
        // Disable drag selection
    }
}

// MARK: - Linkifier

private enum Linkifier {
    static func makeAttributedString(from text: String, baseFont: NSFont, baseColor: NSColor) -> NSAttributedString {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: baseFont,
            .foregroundColor: baseColor
        ])

        // Detect URLs and add .link attribute
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            detector.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
                guard let match, let url = match.url else { return }

                attr.addAttribute(.link, value: url, range: match.range)

                // Optional: make links look like links (safe + lightweight)
                attr.addAttribute(.foregroundColor, value: NSColor.linkColor, range: match.range)
                attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }

        return attr
    }
}
