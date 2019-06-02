import FluentSQLite
import Authentication
import Leaf
import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    // Register providers first
    try services.register(FluentSQLiteProvider())
    try services.register(AuthenticationProvider())
    try services.register(LeafProvider())

    // Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    // Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(SessionsMiddleware.self)
    services.register(middlewares)

    // Configure a SQLite database
    // let sqlite = try SQLiteDatabase(storage: .file(path: "/app/base.sqlite"))
    let sqlite = try SQLiteDatabase(storage: .file(path: "base.sqlite"))


    // Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: sqlite, as: .sqlite)
    databases.enableReferences(on: .sqlite)
    services.register(databases)

    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .sqlite)
    migrations.add(model: Article.self, database: .sqlite)
    migrations.add(model: Tag.self, database: .sqlite)
    migrations.add(model: ArticleTagPivot.self, database: .sqlite)
    migrations.add(migration: AdminUser.self, database: .sqlite)
    services.register(migrations)
    
    config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)
}
