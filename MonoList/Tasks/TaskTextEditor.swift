import AppKit
import SwiftUI

struct TaskTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var fontSize: CGFloat = NSFont.systemFontSize
    var fontWeight: NSFont.Weight = .regular
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> TaskSubmitTextView {
        let view = TaskSubmitTextView()
        view.font = .systemFont(ofSize: fontSize, weight: fontWeight)
        view.isRichText = false
        view.drawsBackground = false
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = true
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.onTextChange = { text = $0 }
        view.onFocusChange = { isFocused = $0 }
        view.onSubmit = onSubmit
        return view
    }

    func updateNSView(_ view: TaskSubmitTextView, context: Context) {
        view.font = .systemFont(ofSize: fontSize, weight: fontWeight)
        if view.string != text {
            view.string = text
            view.invalidateIntrinsicContentSize()
        }
        view.onTextChange = { text = $0 }
        view.onFocusChange = { isFocused = $0 }
        view.onSubmit = onSubmit

        if isFocused, view.window?.firstResponder !== view {
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                view.window?.makeFirstResponder(view)
            }
        } else if !isFocused, view.window?.firstResponder === view {
            view.window?.makeFirstResponder(nil)
        }
    }
}

final class TaskSubmitTextView: NSTextView {
    var onTextChange: ((String) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var onSubmit: (() -> Void)?

    override var intrinsicContentSize: NSSize {
        guard let textContainer, let layoutManager else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 16)
        }
        layoutManager.ensureLayout(for: textContainer)
        let height = ceil(layoutManager.usedRect(for: textContainer).height)
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: max(16, height)
        )
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
        onTextChange?(string)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onFocusChange?(true)
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onFocusChange?(false)
        }
        return resigned
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([
            .command,
            .option,
            .control,
            .shift,
        ])
        guard modifiers == .command,
              let character = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch character {
        case "a":
            selectAll(nil)
        case "c":
            copy(nil)
        case "x":
            cut(nil)
        case "v":
            paste(nil)
        default:
            return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func doCommand(by selector: Selector) {
        let submits = selector == #selector(NSResponder.insertNewline(_:)) ||
            selector == #selector(NSResponder.insertLineBreak(_:)) ||
            selector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
        if submits, !hasMarkedText() {
            onSubmit?()
            return
        }
        super.doCommand(by: selector)
    }
}
