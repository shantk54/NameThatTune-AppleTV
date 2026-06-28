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

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""

            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if cleaned.count >= 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    sender.resignFirstResponder()
                    self.onSubmit()
                }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            onSubmit()
            return true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            text = textField.text ?? ""
            onSubmit()
        }
    }
}
