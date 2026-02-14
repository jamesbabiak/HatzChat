import SwiftUI

struct MarkdownText: View {
    let text: String

    // Tunables (kept minimal and safe)
    private let hintIconSize: CGFloat = 11
    private let hintPadding: CGFloat = 6

    var body: some View {
        // A vertical scroll is handled by the outer chat ScrollView.
        // This adds horizontal scrolling *only when needed* (e.g., long URLs, hashes, base64, code lines).
        ScrollView(.horizontal) {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Helps the system find break opportunities; still won’t break very long single “words”
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)
        }
        .scrollIndicators(.visible) // "visible" but may still be governed by system prefs
        .overlay(alignment: .bottomTrailing) {
            // If the system hides scrollbars on this machine, provide a stable visual hint
            // that more content may exist horizontally.
            if likelyNeedsHorizontalScroll(text) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: hintIconSize, weight: .semibold))
                    Text("scroll")
                        .font(.system(size: hintIconSize, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, hintPadding)
                .padding(.vertical, 4)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.trailing, 4)
                .padding(.bottom, 2)
                .allowsHitTesting(false)
            }
        }
    }

    /// Fast, safe heuristic to determine if horizontal scrolling is *likely* needed.
    /// We avoid any measuring/layout feedback loops. This is deterministic and won't crash.
    ///
    /// - Long unbroken “words” (no spaces) are what won't wrap and cause horizontal overflow.
    /// - We check the longest token length and some common patterns like long URLs/base64/hex.
    private func likelyNeedsHorizontalScroll(_ s: String) -> Bool {
        // Early outs: short strings are fine
        if s.count < 120 { return false }

        // Look for very long tokens (no whitespace)
        // This catches hashes, long URLs, base64, single-line code, etc.
        let tokens = s.split { $0.isWhitespace || $0.isNewline }
        let longest = tokens.map { $0.count }.max() ?? 0
        if longest >= 60 { return true }

        // Heuristics for common "unbroken" content even if separated by punctuation
        // (e.g., URLs with no spaces, JSON blobs, stack traces, etc.)
        if s.contains("http://") || s.contains("https://") { return true }
        if s.contains("{") && s.contains("}") && s.count > 300 { return true }

        return false
    }
}
