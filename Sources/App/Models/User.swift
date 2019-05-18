import Vapor
import FluentSQLite
import Authentication


final class User: Codable {
    
    var id: UUID?
    var name: String
    var username: String
    var password: String
    var pictureProfile: String?
    var biography: String?
    
    
    init(name: String,
         username: String,
         password: String,
         profilePicture: String? = nil,
         biography: String? = nil) {
        self.name = name
        self.username = username
        self.password = password
        self.pictureProfile = profilePicture
        self.biography = biography
    }
    
    
    
}

// MARK: - Vapor and Fluent Extensions
extension User: Parameter {}
extension User: Content {}
extension User: SQLiteUUIDModel {}
extension User: Migration {
    
    // 2 users can't have the same username
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.username)
        }
    }
}

extension User {
    
    var articles: Children<User, Article> {
        return children(\.authorID)
    }
}

// MARK: - AuthenticationSession extensions

extension User: BasicAuthenticatable {
    static var usernameKey: UsernameKey = \User.username
    static var passwordKey: PasswordKey = \User.password
}

extension User: PasswordAuthenticatable {}
extension User: SessionAuthenticatable {}


// MARK: - Author.Public
extension User {
    
    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String
        var pictureProfile: String?
        var biography: String?
        
        init(id: UUID,
             name: String,
             username: String,
             profilePicture: String? = nil,
             biography: String? = nil) {
            self.id = id
            self.name = name
            self.username = username
            self.pictureProfile = profilePicture
            self.biography = biography
        }
    }
    
    func convertToPublic() -> User.Public {
        return User.Public(id: self.id!,
                           name: self.name,
                           username: self.username,
                           profilePicture: self.pictureProfile,
                           biography: self.biography)
    }
}

extension Future where T: User {
    func convertToPublic() -> Future<User.Public> {
        return self.map(to: User.Public.self) { author in
            return author.convertToPublic()
        }
    }
}

// MARK: - AdminUser
// L'user créé lors de la création de la base
struct AdminUser: Migration {
    
    typealias Database = SQLiteDatabase
    
    static func prepare(on conn: SQLiteConnection) -> Future<Void> {
        let password = try? BCrypt.hash("password")
        guard let hashedPassword = password else {
            fatalError("Failed to create initial admin user")
        }
        let user = User(name: "Administrateur", username: "admin", password: hashedPassword)
        return user.save(on: conn).transform(to: ())
    }
    
    static func revert(on conn: SQLiteConnection) -> Future<Void> {
        return .done(on: conn)
    }
}
