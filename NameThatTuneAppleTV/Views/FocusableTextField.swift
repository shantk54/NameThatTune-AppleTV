
import SwiftUI
import UIKit

struct FocusableTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var becomeFirstResponder: Bool
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 28)
        textField.textAlignment = .center
        textField.borderStyle = .roundedRect
        textField.delegate = context.coordinator

        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text

        if becomeFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        var onSubmit: () -> Void

        private var submitTask: Task<Void, Never>?
        private var hasSubmitted = false

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        private func submitOnce(_ textField: UITextField? = nil) {
            guard !hasSubmitted else { return }
            hasSubmitted = true
            submitTask?.cancel()
            textField?.resignFirstResponder()
            onSubmit()
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

            submitTask?.cancel()

            guard cleaned.count >= 3 else { return }

            submitTask = Task { [weak self, weak sender] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self?.submitOnce(sender)
                }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            submitOnce(textField)
            return true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            text = textField.text ?? ""
            submitOnce(textField)
        }
    }
}
