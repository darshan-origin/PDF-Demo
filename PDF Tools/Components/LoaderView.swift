import UIKit

final class LoaderView {

    static let shared = LoaderView()
    private init() {}
    private var backgroundView: UIView?
    private var containerView: UIView?

    func show(on view: UIView) {
        if backgroundView != nil { return }

        let bgView = UIView(frame: view.bounds)
        bgView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        container.layer.cornerRadius = 6
        container.clipsToBounds = true

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Loading..."
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(bgView)
        bgView.addSubview(container)
        container.addSubview(spinner)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: bgView.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: bgView.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 80),
            container.heightAnchor.constraint(equalToConstant: 80),

            spinner.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),

            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4)
        ])

        self.backgroundView = bgView
        self.containerView = container
    }

    func hide() {
        backgroundView?.removeFromSuperview()
        containerView?.removeFromSuperview()
        backgroundView = nil
        containerView = nil
    }
}
