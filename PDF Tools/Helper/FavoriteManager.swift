import Foundation

class FavoriteManager {
    static let shared = FavoriteManager()
    
    private init() {}
    
    private(set) var favoriteFiles: [FilesMetaDataModel] = []
    
    func toggleFavorite(_ file: FilesMetaDataModel) {
        if let index = favoriteFiles.firstIndex(where: { $0.url == file.url }) {
            favoriteFiles.remove(at: index)
        } else {
            favoriteFiles.append(file)
        }
        Logger.print("Favourite Files: \(favoriteFiles)", level: .success)
    }
    
    func isFavorite(_ file: FilesMetaDataModel) -> Bool {
        return favoriteFiles.contains { $0.url == file.url }
    }
    
    func isFavorite(url: URL) -> Bool {
        return favoriteFiles.contains { $0.url == url }
    }
    
    func updateFavorite(_ file: FilesMetaDataModel) {
        if let index = favoriteFiles.firstIndex(where: { $0.url == file.url }) {
            favoriteFiles[index] = file
        }
    }
    
    func removeFavorite(url: URL) {
        if let index = favoriteFiles.firstIndex(where: { $0.url == url }) {
            favoriteFiles.remove(at: index)
        }
    }
}
