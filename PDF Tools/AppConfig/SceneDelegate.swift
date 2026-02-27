import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        
        if isPasswordProtected {
            showSecurityScreen()
        } else {
            showMainScreen()
        }
    }

    private func showSecurityScreen() {
        let vc = SecurityVC()
        if SecurityManager.shared.isPINSet {
            vc.state = .unlock
        } else {
            vc.state = .setPIN
        }
        
        vc.onUnlockSuccess = { [weak self] in
            self?.showMainScreen()
        }
        
        window?.rootViewController = vc
        window?.makeKeyAndVisible()
    }

    private func showMainScreen() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let tabVC = storyboard.instantiateViewController(withIdentifier: "TabVC")
        window?.rootViewController = tabVC
        window?.makeKeyAndVisible()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        if isPasswordProtected && !(window?.rootViewController is SecurityVC) {
            if SecurityManager.shared.isPINSet {
                showSecurityScreen()
            }
        }
    }
}
