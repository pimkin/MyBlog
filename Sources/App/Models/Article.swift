import FluentSQLite
import Vapor

final class Article: Codable {
    
    var id: UUID?
    var title: String
    var slugURL: String
    var content: String
    var snippet: String
    var authorID: User.ID
    var creationDate: Date
    var editionDate: Date?
    var published: Bool
    
    
    
    init(title: String,
         slugURL: String,
         content: String,
         snippet: String,
         authorID: User.ID,
         creationDate: Date,
         published: Bool) {
        self.title = title
        self.slugURL = slugURL
        self.content = content
        self.snippet = snippet
        self.authorID = authorID
        self.creationDate = creationDate
        self.published = published
    }
}

extension Article: Parameter {}
extension Article: Content {}
extension Article: SQLiteUUIDModel {}
extension Article: Migration {}

extension Article {
    
    var author: Parent<Article, User> {
        return parent(\.authorID)
    }
    
    var tags: Siblings<Article, Tag, ArticleTagPivot> {
        return siblings()
    }
}

extension Article {
    final class Leaffed: Encodable {
        
        var id: UUID
        var title: String
        var slugURL: String
        var content: String
        var snippet: String
        var creationDate: String
        var authorName: String
        var tagsNames: [String]
        
        
        init(withArticle article: Article, authorName: String, tagsNames: [String]) {
            guard let id = article.id else { fatalError("article should have an id") }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy hh:mma"
            
            self.id = id
            self.title = article.title
            self.slugURL = article.slugURL
            self.content = article.content
            self.snippet = article.snippet
            self.creationDate = dateFormatter.string(from: article.creationDate)
            self.authorName = authorName
            self.tagsNames = tagsNames
            
        }
    }
    
    func leaf(on req: Request) throws -> Future<Article.Leaffed> {
        
        let authorFuture = self.author.get(on: req)
        let tagsFuture = try self.tags.query(on: req).all()
        
        return map(to: Article.Leaffed.self, authorFuture, tagsFuture) { author, tags in
            
                        let authorName = author.username
                        let tagsNames = tags.map { $0.name }
                        return Article.Leaffed(withArticle: self,
                                               authorName: authorName,
                                               tagsNames: tagsNames)
        }
    }
}

extension Collection where Element: Article {
    func leaf(on req: Request) throws -> Future<[Article.Leaffed]> {
        var result = [Future<Article.Leaffed>]()
        for article in self {
            try result.append(article.leaf(on: req))
        }
        return result.flatten(on: req)
    }
}

