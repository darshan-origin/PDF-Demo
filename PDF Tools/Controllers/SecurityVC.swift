import UIKit
import LocalAuthentication

enum SecurityState {
    case setPIN
    case confirmPIN(firstEntry: String)
    case unlock
}

class RoundButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        layer.masksToBounds = true
    }
}

class SecurityVC: UIViewController {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter PIN"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    private let lockImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "lock.fill")
        iv.tintColor = .systemRed
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private let indicatorStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    } ()
    
    private let keypadStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 15
        stack.distribution = .fillEqually
        return stack
    }()
    
    private var indicators: [UIView] = []
    private var enteredPIN: String = ""
    var state: SecurityState = .unlock
    var onUnlockSuccess: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateStateUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGray6
        
        view.addSubview(lockImageView)
        lockImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lockImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            lockImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            lockImageView.widthAnchor.constraint(equalToConstant: 80),
            lockImageView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        view.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: lockImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        view.addSubview(indicatorStackView)
        indicatorStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicatorStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            indicatorStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            indicatorStackView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        for _ in 0..<4 {
            let dot = UIView()
            dot.backgroundColor = .clear
            dot.layer.borderWidth = 1
            dot.layer.borderColor = UIColor.lightGray.cgColor
            dot.layer.cornerRadius = 25 // 50 / 2
            dot.layer.masksToBounds = true
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 50),
                dot.heightAnchor.constraint(equalToConstant: 50)
            ])
            indicatorStackView.addArrangedSubview(dot)
            indicators.append(dot)
        }
        
        let keypadContainer = UIView()
        keypadContainer.backgroundColor = .white.withAlphaComponent(0.5)
        keypadContainer.layer.cornerRadius = 50
        view.addSubview(keypadContainer)
        keypadContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keypadContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keypadContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keypadContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keypadContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6)
        ])
        
        keypadContainer.addSubview(keypadStackView)
        keypadStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            keypadStackView.topAnchor.constraint(equalTo: keypadContainer.topAnchor, constant: 30),
            keypadStackView.leadingAnchor.constraint(equalTo: keypadContainer.leadingAnchor, constant: 40),
            keypadStackView.trailingAnchor.constraint(equalTo: keypadContainer.trailingAnchor, constant: -40),
            keypadStackView.bottomAnchor.constraint(equalTo: keypadContainer.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        setupKeypad()
    }
    
    private func setupKeypad() {
        let keys = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            ["back", "0", "biometric"]
        ]
        
        for row in keys {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 20
            rowStack.distribution = .fillEqually
            keypadStackView.addArrangedSubview(rowStack)
            
            for key in row {
                let button = RoundButton(type: .system)
                button.backgroundColor = .white.withAlphaComponent(0.8)
                button.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
                button.setTitleColor(.black, for: .normal)
                
                button.translatesAutoresizingMaskIntoConstraints = false
                button.heightAnchor.constraint(equalTo: button.widthAnchor).isActive = true
                
                if key == "back" {
                    button.setImage(UIImage(systemName: "delete.left"), for: .normal)
                    button.tintColor = .black
                } else if key == "biometric" {
                    button.setImage(UIImage(systemName: "faceid"), for: .normal)
                    button.backgroundColor = .systemRed.withAlphaComponent(0.8)
                    button.tintColor = .white
                } else {
                    button.setTitle(key, for: .normal)
                }
                
                button.tag = (Int(key) ?? (key == "back" ? -1 : -2))
                button.addTarget(self, action: #selector(keypadTapped(_:)), for: .touchUpInside)
                rowStack.addArrangedSubview(button)
            }
        }
    }
    
    private func updateStateUI() {
        switch state {
        case .setPIN:
            titleLabel.text = "Set The PIN"
        case .confirmPIN:
            titleLabel.text = "Re-Enter The PIN"
        case .unlock:
            titleLabel.text = "Enter Your PIN"
        }
        enteredPIN = ""
        updateIndicators()
    }
    
    @objc private func keypadTapped(_ sender: UIButton) {
        if sender.tag >= 0 {
            if enteredPIN.count < 4 {
                enteredPIN.append("\(sender.tag)")
                UISelectionFeedbackGenerator().selectionChanged()
            }
        } else if sender.tag == -1 { // Back
            if !enteredPIN.isEmpty {
                enteredPIN.removeLast()
            }
        } else if sender.tag == -2 { // Biometric
            handleBiometrics()
            return
        }
        
        updateIndicators()
        
        if enteredPIN.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.handlePINCompletion()
            }
        }
    }
    
    private func updateIndicators() {
        for (index, dot) in indicators.enumerated() {
            if index < enteredPIN.count {
                dot.backgroundColor = .white
                dot.layer.borderColor = UIColor.lightGray.cgColor
                if dot.subviews.isEmpty {
                    let label = UILabel()
                    label.text = "*"
                    label.font = .systemFont(ofSize: 30, weight: .bold)
                    label.textAlignment = .center
                    label.textColor = .black
                    label.translatesAutoresizingMaskIntoConstraints = false
                    dot.addSubview(label)
                    NSLayoutConstraint.activate([
                        label.centerXAnchor.constraint(equalTo: dot.centerXAnchor),
                        label.centerYAnchor.constraint(equalTo: dot.centerYAnchor, constant: 5)
                    ])
                }
            } else {
                dot.backgroundColor = .clear
                dot.layer.borderColor = UIColor.lightGray.cgColor
                dot.subviews.forEach { $0.removeFromSuperview() }
            }
        }
    }
    
    private func handlePINCompletion() {
        switch state {
        case .setPIN:
            state = .confirmPIN(firstEntry: enteredPIN)
            updateStateUI()
        case .confirmPIN(let firstEntry):
            if enteredPIN == firstEntry {
                SecurityManager.shared.setPIN(enteredPIN)
                dismissOrNavigate()
            } else {
                showAlert(message: "PIN mismatch. Please try again.")
                state = .setPIN
                updateStateUI()
            }
        case .unlock:
            if SecurityManager.shared.verifyPIN(enteredPIN) {
                dismissOrNavigate()
            } else {
                showAlert(message: "Incorrect PIN")
                enteredPIN = ""
                updateIndicators()
            }
        }
    }
    
    private func handleBiometrics() {
        SecurityManager.shared.authenticateWithBiometrics { success, error in
            if success {
                self.dismissOrNavigate()
            } else if let error = error {
                print("Biometric error: \(error)")
            }
        }
    }
    
    private func dismissOrNavigate() {
        if let onUnlockSuccess = onUnlockSuccess {
            onUnlockSuccess()
        } else {
            self.dismiss(animated: true)
        }
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
