import UIKit

@main final class App: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = Scene.self
        return config
    }
}

final class Scene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = Lab()
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class TestField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "vi" } ?? super.textInputMode
    }
}

final class Lab: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
        ])
        let first = TestField(), second = TestField()
        for (field, identifier) in [(first, "first"), (second, "second")] {
            field.accessibilityIdentifier = identifier
            field.borderStyle = .roundedRect
            field.autocorrectionType = .no
            stack.addArrangedSubview(field)
        }
        let move = UIButton(type: .system)
        move.setTitle("Move before last character", for: .normal)
        move.addAction(UIAction { _ in
            guard let p = first.position(from: first.endOfDocument, offset: -1) else { return }
            first.selectedTextRange = first.textRange(from: p, to: p)
        }, for: .touchUpInside)
        stack.addArrangedSubview(move)

        let select = UIButton(type: .system)
        select.setTitle("Select middle of first word", for: .normal)
        select.addAction(UIAction { _ in
            guard let start = first.position(from: first.beginningOfDocument, offset: 1),
                  let end = first.position(from: first.endOfDocument, offset: -1) else { return }
            first.selectedTextRange = first.textRange(from: start, to: end)
        }, for: .touchUpInside)
        stack.addArrangedSubview(select)

        let end = UIButton(type: .system)
        end.setTitle("Place caret at end of first field", for: .normal)
        end.addAction(UIAction { _ in
            let p = first.endOfDocument
            first.selectedTextRange = first.textRange(from: p, to: p)
        }, for: .touchUpInside)
        stack.addArrangedSubview(end)
    }
}
