import UIKit

final class AlertHelper {
    
    static let shared = AlertHelper()
    private init() {}
    
    // MARK: - Simple Alert With Result
    func show(
        on viewController: UIViewController,
        title: String?,
        message: String?,
        style: UIAlertController.Style = .alert,
        actions: [(title: String, style: UIAlertAction.Style, handler: (() -> Void)?)] = [("OK", .default, nil)]
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        
        actions.forEach { action in
            let alertAction = UIAlertAction(title: action.title, style: action.style) { _ in
                action.handler?()
            }
            alert.addAction(alertAction)
        }
        
        viewController.present(alert, animated: true)
    }
    
    func showAlert(
        on vc: UIViewController,
        title: String?,
        message: String?,
        style: UIAlertController.Style = .alert,
        actions: [(title: String, style: UIAlertAction.Style)] = [("OK", .default)],
        completion: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message,preferredStyle: style)
        
        actions.forEach { action in
            let alertAction = UIAlertAction(title: action.title, style: action.style) { _ in
                completion(action.title)
            }
            alert.addAction(alertAction)
        }
        
        vc.present(alert, animated: true)
    }
    
    func showInfoAlert(
        on vc: UIViewController,
        title: String?,
        message: String?,
        style: UIAlertController.Style = .alert,
        actions: [(title: String, style: UIAlertAction.Style)] = [("OK", .default)],
        completion: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        
        actions.forEach { action in
            let alertAction = UIAlertAction(title: action.title, style: action.style) { _ in
                completion(action.title)
            }
            alert.addAction(alertAction)
        }
        
        vc.present(alert, animated: true)
    }
    
    func textFieldAlert(
        title: String,
        placeHolder: String,
        vc: UIViewController,
        saprated: Bool,
        keyboardType: UIKeyboardType = .default,
        completion: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in textField.placeholder = placeHolder
            textField.keyboardType = keyboardType
            
            if saprated {
                textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        })
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            guard let text = alert.textFields?.first?.text?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                completion(nil)
                return
            }
            completion(text)
        })
        
        vc.present(alert, animated: true)
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text else { return }
        let cleanText = text.replacingOccurrences(of: ",", with: "")
        let separatedText = cleanText.map { String($0) }.joined(separator: ",")
        
        textField.text = separatedText
    }
    
     func showFolderSelectionSheet(
        folders: [FolderModel],
        title: String,
        message: String? = nil,
        on: UIViewController,
        completion: @escaping (FolderModel) -> Void
    ) {
        
        guard !folders.isEmpty else {
            Logger.print("No folders available", level: .warning)
            return
        }
        
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .actionSheet
        )
        
        folders.forEach { folder in
            alert.addAction(UIAlertAction(title: folder.name, style: .default) { _ in
                completion(folder)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = on.view
            popover.sourceRect = CGRect(
                x: on.view.bounds.midX,
                y: on.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        
        on.present(alert, animated: true)
    }
}


