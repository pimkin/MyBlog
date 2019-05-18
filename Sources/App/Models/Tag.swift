import Vapor
import FluentSQLite

final class Tag: Codable {
    
    var id: UUID?
    var name: String
    var description: String
    
    init(name: String, description: String) {
        self.name = name
        self.description = description
    }
    
}

extension Tag: Parameter {}
extension Tag: SQLiteUUIDModel {}
extension Tag: Content {}
extension Tag: Migration {
    
    // 2 Tags must not have the same name
    static func prepare(on connection: SQLiteConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.name)
        }
    }
    
}

extension Tag {
    
    var articles: Siblings<Tag, Article, ArticleTagPivot> {
        return siblings()
    }
    
}


