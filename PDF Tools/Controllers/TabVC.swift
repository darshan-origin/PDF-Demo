import UIKit

class TabVC: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }
    
    private func setupTabs() {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeVC") as? HomeVC else {
            fatalError("HomeVC not found")
        }
        
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.setNavigationBarHidden(true, animated: false)
        homeNav.navigationBar.prefersLargeTitles = false
        homeNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        
        guard let myWorksVC = storyboard.instantiateViewController(withIdentifier: "MyWorksVC") as? MyWorksVC else {
            fatalError("MyWorksVC not found")
        }
        
        let editNav = UINavigationController(rootViewController: myWorksVC)
        editNav.setNavigationBarHidden(true, animated: false)
        editNav.navigationBar.prefersLargeTitles = false
        editNav.tabBarItem = UITabBarItem(
            title: "My Works",
            image: UIImage(systemName: "doc"),
            selectedImage: UIImage(systemName: "doc.fill")
        )
        
        
        guard let favVC = storyboard.instantiateViewController(withIdentifier: "FavVC") as? FavVC else {
            fatalError("FavVC not found")
        }
        
        let favNav = UINavigationController(rootViewController: favVC)
        favNav.setNavigationBarHidden(true, animated: false)
        favNav.navigationBar.prefersLargeTitles = false
        favNav.tabBarItem = UITabBarItem(
            title: "Favourites",
            image: UIImage(systemName: "heart"),
            selectedImage: UIImage(systemName: "heart.fill")
        )
        
        
        viewControllers = [homeNav, editNav, favNav]
    }
}
