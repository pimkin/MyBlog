import Vapor
import FluentSQLite

final class ArticleTagPivot: SQLiteUUIDPivot {
    
    var id: UUID?
    var articleID: Article.ID
    var tagID: Tag.ID
    
    typealias Left = Article
    typealias Right = Tag
    
    static var leftIDKey: LeftIDKey = \.articleID
    static var rightIDKey: RightIDKey = \.tagID
    
    init(_ article: Article, _ tag: Tag) throws {
        self.articleID = try article.requireID()
        self.tagID = try tag.requireID()
    }
    
}


extension ArticleTagPivot: ModifiablePivot {}

extension ArticleTagPivot: Migration {}
