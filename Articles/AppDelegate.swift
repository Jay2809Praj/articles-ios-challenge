import Swinject
import UIKit
import XCGLogger

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    /// The composition root. Everything the app needs is registered here once
    /// and resolved from the outside in – no type creates its own dependencies.
    let container: Container = {
        let container = Container()
        AppDelegate.registerDependencies(in: container)
        return container
    }()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        container.resolve(XCGLogger.self)?.info("Application launched")
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - Swinject container setup

private extension AppDelegate {
    static func registerDependencies(in container: Container) {
        registerClients(in: container)
        registerProviders(in: container)
        registerManagers(in: container)
    }

    /// Low-level utilities shared by the other layers.
    static func registerClients(in container: Container) {
        container.register(XCGLogger.self) { _ in
            LoggerFactory.makeLogger()
        }
        .inObjectScope(.container)

        container.register(NetworkClientProtocol.self) { resolver in
            let logger = resolver.resolve(XCGLogger.self)!
            let session = NetworkSessionFactory.makeSession(eventMonitors: [NetworkEventLogger(logger: logger)])
            return NetworkClient(session: session)
        }
        .inObjectScope(.container)

        container.register(ArticlesCacheProtocol.self) { resolver in
            ArticlesCache(logger: resolver.resolve(XCGLogger.self)!)
        }
        .inObjectScope(.container)
    }

    /// Implementations of the protocols in `Models/ProviderProtocols`.
    static func registerProviders(in container: Container) {
        container.register(ArticlesProviderProtocol.self) { resolver in
            ArticlesProvider(
                client: resolver.resolve(NetworkClientProtocol.self)!,
                logger: resolver.resolve(XCGLogger.self)!
            )
        }

        container.register(ReachabilityProviderProtocol.self) { resolver in
            ReachabilityProvider(logger: resolver.resolve(XCGLogger.self)!)
        }
        .inObjectScope(.container)
    }

    /// The only layer view controllers are allowed to talk to.
    static func registerManagers(in container: Container) {
        container.register(ArticlesManagerProtocol.self) { resolver in
            ArticlesManager(
                provider: resolver.resolve(ArticlesProviderProtocol.self)!,
                cache: resolver.resolve(ArticlesCacheProtocol.self)!,
                logger: resolver.resolve(XCGLogger.self)!
            )
        }
        .inObjectScope(.container)

        container.register(ConnectivityManagerProtocol.self) { resolver in
            ConnectivityManager(provider: resolver.resolve(ReachabilityProviderProtocol.self)!)
        }
        .inObjectScope(.container)
    }
}
