import Vapor
import FluentSQL

final class ArticleTextinator {
    
    static let separator = "----article----"
    static let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--snippet--", "--slugURL--", "--title--"]
    
    let dateFormatter = DateFormatter()
    
    init() {
        dateFormatter.dateFormat = "MM/dd/yyyy hh:mma"
    }
    
    func textFrom(leaffedArticle: Article.Leaffed) -> String {
        
        var text = "----article----\r\n"
        text = text + "--title--\r\n" + "\(leaffedArticle.title)\r\n"
        text = text + "--slugURL--\r\n" + "\(leaffedArticle.slugURL)\r\n"
        
        if leaffedArticle.tags.count >= 1 {
            let tagNames = leaffedArticle.tags.joined(separator: "--")
            text = text + "--tags--\r\n" + "\(tagNames)\r\n"
        }
        
        text = text + "--snippet--\r\n" + "\(leaffedArticle.snippet)\r\n"
        text = text + "--created--\r\n" + "\(leaffedArticle.created)\r\n"
        if let edited = leaffedArticle.edited {
            text = text + "--edited--\r\n" + "\(edited)\r\n"
        }
        if let published = leaffedArticle.published {
            text = text + "--published--\r\n" + "\(published)\r\n"
        }
        if let mainPicture = leaffedArticle.mainPicture {
            text = text + "--mainPicture--\r\n" + "\(mainPicture)\r\n"
        }
        text = text + "--content--\r\n" + "\(leaffedArticle.content)\r\n"
        
        return text
    }
    
    func textFileFrom(futureArticle: Future<Article>, on req: Request) throws -> Future<Response> {
        
        return futureArticle.flatMap(to: Response.self) { article in
            return try article.leaf(on: req).map(to: Response.self) { leaffedArticle in
                
                let text = self.textFrom(leaffedArticle: leaffedArticle)
                let filename = "\(leaffedArticle.slugURL).txt"
                let data = text.convertToData()
                let response = req.response(data, as: .plainText)
                response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
                return response
            }
        }
    }
    
    func textFileFromAllArticles(on req: Request) throws -> Future<Response> {
        
        let user = try req.requireAuthenticated(User.self)
        let userID = try user.requireID()
        
        return Article.query(on: req).filter(\.authorID == userID).all().flatMap(to: Response.self) { articles in
            
            return try articles.leaf(on: req).map(to: Response.self) { leaffedArticles in
                var resultText = ""
                for leaffedArticle in leaffedArticles {
                    let text = self.textFrom(leaffedArticle: leaffedArticle)
                    resultText = resultText + text
                }
                
                let data = resultText.convertToData()
                let response = req.response(data, as: .plainText)
                response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"articles.txt\"")
                return response
            }
        }
        
    }
    
    func articleFromText(text: String, on req: Request) throws -> Future<Article> {
        
        var textArticle = text
        
        let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--snippet--", "--tags--", "--slugURL--", "--title--"]
        var articleDictionary: [String: String] = [String: String]()
        for identifier in identifiers {
            let components = textArticle.components(separatedBy: identifier)
            if let restOfComponents = components.first,
                let component = components.last {
                textArticle = restOfComponents
                articleDictionary[identifier] = component
            }
        }
        
        guard let title = articleDictionary["--title--"],
            let slugURL = articleDictionary["--slugURL--"],
            let snippet = articleDictionary["--snippet--"],
            let createdString = articleDictionary["--created--"],
            let created = dateFormatter.date(from : createdString),
            let mainPicture = articleDictionary["--mainPicture--"],
            let content = articleDictionary["--content--"] else {
                throw Abort(.internalServerError)
        }
        
        var published: Date? = nil
        if let publishedString = articleDictionary["--published--"] {
            published = dateFormatter.date(from: publishedString)
        }
        
        var edited: Date? = nil
        if let editedString = articleDictionary["--edited--"] {
            edited = dateFormatter.date(from: editedString)
        }
        
        let user = try req.requireAuthenticated(User.self)
        
        return Article(title: title,
                       slugURL: slugURL,
                       content: content,
                       snippet: snippet,
                       authorID: try user.requireID(),
                       created: created,
                       edited: edited,
                       published: published,
                       mainPicture: mainPicture).save(on: req).flatMap(to: Article.self) { article in
                        
                        var attachFutureTags = [Future<ArticleTagPivot>]()
                        
                        if let tags = articleDictionary["--tags--"] {
                            let tagNames = tags.components(separatedBy: "--")
                            
                            
                            for tag in tagNames {
                                let attachFutureTag = Tag.query(on: req).filter(\.name == tag).first().flatMap(to: ArticleTagPivot.self) { tag in
                                    
                                    guard let tag = tag else { fatalError()}
                                    
                                    return article.tags.attach(tag, on: req)
                                }
                                attachFutureTags.append(attachFutureTag)
                            }
                            
                        }
                        return attachFutureTags.flatten(on: req).transform(to: article)
        }
    }
    
    
    
    func articlesFromFile(file: File, on req: Request) throws -> Future<[Article]> {
        
        let txtData = file.data
        guard var articlesTxt = String(data: txtData, encoding: .utf8) else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        
        articlesTxt = articlesTxt.replacingOccurrences(of: "\r", with: "")
        articlesTxt = articlesTxt.replacingOccurrences(of: "\n", with: "")
        
        // Split txt file with separator between articles
        let separator = "----article----"
        var textArticles = articlesTxt.components(separatedBy: separator)
        textArticles = textArticles.filter { textArticle -> Bool in
            return textArticle != ""
        }
        
        
        var articlesFuture = [Future<Article>]()
        for textArticle in textArticles {
            
            let futureArticle = try articleFromText(text: textArticle, on: req)
            articlesFuture.append(futureArticle)
        }
        
        return articlesFuture.flatten(on: req)
    }
    
    
}
