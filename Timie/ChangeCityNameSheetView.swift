import SwiftUI
import UIKit

struct ChangeCityNameSheetView: View {
    let city: City
    let onSave: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customName: String = ""
    @State private var baselineDisplayName: String
    @State private var isNameFieldFocused = false

    init(city: City, onSave: @escaping (String?) -> Void) {
        self.city = city
        self.onSave = onSave
        _baselineDisplayName = State(initialValue: city.displayName)
    }

    private var originalName: String {
        city.canonicalCity.name
    }

    private var trimmedCustomName: String {
        customName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedOriginalName: String {
        originalName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSavedDisplayName: String {
        city.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBaselineDisplayName: String {
        let trimmed = baselineDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? trimmedOriginalName : trimmed
    }

    private var pendingDisplayName: String {
        trimmedCustomName.isEmpty ? trimmedBaselineDisplayName : trimmedCustomName
    }

    private var hasSavedCustomDisplayName: Bool {
        !(city.customDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var shouldShowSaveButton: Bool {
        pendingDisplayName != trimmedSavedDisplayName
    }

    private var shouldShowRestoreOriginalButton: Bool {
        hasSavedCustomDisplayName || pendingDisplayName != trimmedOriginalName
    }

    private var isUsingOriginalNameValue: Bool {
        !shouldShowRestoreOriginalButton && trimmedCustomName.isEmpty
    }

    private var bottomAccessoryHeight: CGFloat {
        68
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        NativeCenteredNameTextField(
                            text: $customName,
                            placeholder: trimmedBaselineDisplayName,
                            isFocused: $isNameFieldFocused,
                            onSubmit: {
                                guard shouldShowSaveButton else { return }
                                saveAndDismiss()
                            }
                        )
                        .frame(maxWidth: 420)
                        .frame(height: 58)
                        .clipped()

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .background(
                Color(
                    red: 238.0 / 255.0,
                    green: 238.0 / 255.0,
                    blue: 238.0 / 255.0
                )
                .ignoresSafeArea()
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if shouldShowRestoreOriginalButton {
                        Button {
                            triggerNotificationHaptic(.warning)
                            customName = ""
                            baselineDisplayName = originalName
                            DispatchQueue.main.async {
                                isNameFieldFocused = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 13, weight: .medium))

                                Text("Original")
                                    .font(.system(size: 16, weight: .regular))
                                    .tracking(-0.48)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.88))
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if isUsingOriginalNameValue {
                        Text("For example, the name of the person\nwho lives there")
                            .font(.system(size: 14, weight: .regular))
                            .tracking(-0.42)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.black.opacity(0.2))
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: bottomAccessoryHeight, alignment: .center)
//                .padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.16), value: shouldShowRestoreOriginalButton)
            }
            .navigationTitle("Change Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        } label: {
                            Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                        }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if shouldShowSaveButton {
                        Button("Save") {
                            saveAndDismiss()
                        }
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.41)
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    isNameFieldFocused = true
                }
            }
        }
    }

    private func saveAndDismiss() {
        onSave(normalizedCustomName(from: pendingDisplayName))
        triggerNotificationHaptic(.success)
        dismiss()
    }

    private func normalizedCustomName(from rawValue: String) -> String? {
        guard !rawValue.isEmpty else { return nil }
        guard rawValue != trimmedOriginalName else { return nil }
        return rawValue
    }

    private func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let fire = {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(type)
        }

        if Thread.isMainThread {
            fire()
        } else {
            DispatchQueue.main.async(execute: fire)
        }
    }
}

private struct NativeCenteredNameTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    private var placeholderAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 46, weight: .semibold),
            .foregroundColor: UIColor.black.withAlphaComponent(0.2),
            .kern: -0.96
        ]
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: 46, weight: .semibold)
        textField.adjustsFontForContentSizeCategory = true
        textField.returnKeyType = .done
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .words
        textField.textAlignment = .center
        textField.textColor = .black
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = 20
        textField.backgroundColor = .clear
        textField.borderStyle = .none
        textField.clearButtonMode = .never
        textField.clipsToBounds = true
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.placeholder = placeholder
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: placeholderAttributes
        )
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
            uiView.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: placeholderAttributes
            )
        }

        if isFocused {
            guard !uiView.isFirstResponder else { return }
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool
        private let onSubmit: () -> Void

        init(text: Binding<String>, isFocused: Binding<Bool>, onSubmit: @escaping () -> Void) {
            _text = text
            _isFocused = isFocused
            self.onSubmit = onSubmit
        }

        @objc func textDidChange(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
        }
    }
}
