//
//  Untitled.swift
//  PDF Tools
//
//  Created by mac on 25/02/26.
//

import UIKit

class CommonImageViewerVC: UIViewController {

    private var imageUrl: String
    private var imageView = UIImageView()
    private var closeButton = UIButton(type: .system)

    init(imageUrl: String) {
        self.imageUrl = imageUrl
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageView()
        setupCloseButton()
        loadImage()
    }

    private func setupImageView() {
        imageView.frame = view.bounds
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)
    }

    private func setupCloseButton() {
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 5
        closeButton.frame = CGRect(x: 20, y: 50, width: 70, height: 35)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }

    private func loadImage() {
        guard let url = URL(string: imageUrl) else { return }

        if url.isFileURL {
            // Local file
            if let data = try? Data(contentsOf: url) {
                imageView.image = UIImage(data: data)
            }
        } else {
            // Remote URL
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        self.imageView.image = UIImage(data: data)
                    }
                }
            }.resume()
        }
    }
}
