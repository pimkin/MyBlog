import FluentSQLite
import Vapor

final class Article: Codable {
    
    
    
    var id: UUID?
    var title: String
    var slugURL: String
    var snippet: String
    var content: String
    var authorID: User.ID
    var created: Date
    var edited: Date?
    var published: Date?
    var mainPicture: String?
    
    
    init(title: String,
         slugURL: String,
         content: String,
         snippet: String,
         authorID: User.ID,
         created: Date,
         edited: Date?,
         published: Date?,
         mainPicture: String?) {
        self.title = title
        self.slugURL = slugURL
        self.content = content
        self.snippet = snippet
        self.authorID = authorID
        self.created = created
        self.edited = edited
        self.published = published
        self.mainPicture = mainPicture
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
        var created: String
        var edited: String?
        var published: String?
        var mainPicture: String?
        var authorName: String
        var tags: [String]
        
        
        init(withArticle article: Article, authorName: String, tagsNames: [String]) {
            guard let id = article.id else { fatalError("article should have an id") }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy hh:mma"
            
            self.id = id
            self.title = article.title
            self.slugURL = article.slugURL
            self.content = article.content
            self.snippet = article.snippet
            self.created = dateFormatter.string(from: article.created)
            self.authorName = authorName
            self.tags = tagsNames
            self.mainPicture = article.mainPicture
            
            if let editedDate = article.edited,
                let publishedDate = article.published {
                    self.edited = dateFormatter.string(from: editedDate)
                    self.published = dateFormatter.string(from: publishedDate)
                
            }
            
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

