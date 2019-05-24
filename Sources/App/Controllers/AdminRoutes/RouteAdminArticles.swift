import Vapor
import FluentSQL

final class RouteAdminArticles {
    
    // Mark: - Article Routes
    
    // route for blog.com/admin/articles
    //  get all the articles of the blog (descending)
    func allArticlesHandler(_ req: Request) throws -> Future<View> {
        
        let searchTerm = req.query[String.self, at:"search"]
        let paginator = AdminPaginator(WithPageNumber: 1, forType: .articles(searchTerm: searchTerm))
        
        return Article.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.title ~~ term)
            }
            
            }.range(paginator.rangePlusOne).sort(\.created, .descending).all()
            .flatMap(to: View.self) { articles in
                return try articles.leaf(on: req).flatMap(to: View.self) { fetchedLeaffedArticles in
                    
                    var leaffedArticles = fetchedLeaffedArticles
                    
                    var olderPagePath: String?
                    if fetchedLeaffedArticles.count > paginator.articlesPerPage {
                        leaffedArticles.removeLast()
                        olderPagePath = paginator.olderPagePath
                    }
                    
                    let context = AdminArticlesContext(tabTitle: paginator.tabTitle,
                                                       pageTitle: paginator.pageTitle,
                                                       articles: leaffedArticles,
                                                       olderPagePath: olderPagePath,
                                                       newerPagePath: paginator.newerPagePath)
                    return try req.view().render("admin/articles", context)
                    
                }
                
                
        }
    }
    
    // route for blog.com/admin/articles/page/pageNumber
    //  -> get all the articles of the blog (descending) with pagination
    func allArticlesPageHandler(_ req: Request) throws -> Future<View> {
        let pageNumber = try req.parameters.next(Int.self)
        let searchTerm = req.query[String.self, at:"search"]
        
        let paginator = AdminPaginator(WithPageNumber: pageNumber, forType: .articles(searchTerm: searchTerm))
        
        return Article.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.title ~~ term)
            }
            
            }.range(paginator.rangePlusOne).sort(\.created, .descending).all()
            .flatMap(to: View.self) { articles in
                return try articles.leaf(on: req).flatMap(to: View.self) { fetchedLeaffedArticles in
                    
                    var leaffedArticles = fetchedLeaffedArticles
                    
                    var olderPagePath: String?
                    if fetchedLeaffedArticles.count > paginator.articlesPerPage {
                        leaffedArticles.removeLast()
                        olderPagePath = paginator.olderPagePath
                    }
                    
                    let context = AdminArticlesContext(tabTitle: paginator.tabTitle,
                                                       pageTitle: paginator.pageTitle,
                                                       articles: leaffedArticles,
                                                       olderPagePath: olderPagePath,
                                                       newerPagePath: paginator.newerPagePath)
                    return try req.view().render("admin/articles", context)
                    
                }
                
                
        }
        
    }
    
    // route GET for blog.com/admin/articles/create
    //  -> get request for create a page
    func createArticleHandler(_ req: Request) throws -> Future<View> {
        return Tag.query(on: req).all().flatMap(to: View.self) { tags in
            let context = AdminArticleContext(tabTitle: "MyBlog>Admin",
                                              pageTitle: "Creation Article",
                                              tags: tags,
                                              article: nil,
                                              isEditing: false)
            return try req.view().render("admin/article", context)
        }
    }
    
    // route POST for blog.com/admin/articles/create
    //  -> post request for create a page
    func createArticlePostHandler(_ req: Request, articleData: AdminArticleData) throws -> Future<Response> {
        let author = try req.requireAuthenticated(User.self)
        
        var published: Date?
        if articleData.published != nil {
            published = Date()
        }
        
        let article = Article(title: articleData.title,
                              slugURL: articleData.slugURL,
                              content: articleData.content,
                              snippet: articleData.snippet,
                              authorID: try author.requireID(),
                              created: Date(),
                              edited: nil,
                              published: published,
                              mainPicture: articleData.mainPicture)
        
        return article.save(on: req).flatMap(to: Response.self) { article in
            
            var futures = [Future<ArticleTagPivot>]()
            if let tags = articleData.tags {
                for tag in tags {
                    let attachTagFuture = Tag.query(on: req).filter(\.name == tag).first().flatMap(to: ArticleTagPivot.self) { futureTag in
                        guard let futureTag = futureTag else { fatalError("the tag should exist") }
                        
                        return article.tags.attach(futureTag, on: req)
                    }
                    futures.append(attachTagFuture)
                }
            }
            
            return futures.flatten(on: req).transform(to: req.redirect(to: "/admin/articles"))
        }
    }
    
    // GET route for blog.com/admin/articles/articleID/edit
    func editArticleHandler(_ req: Request) throws -> Future<View> {
        let articleFuture = try req.parameters.next(Article.self)
        let tagsFuture = Tag.query(on: req).all()
        return flatMap(to: View.self, articleFuture, tagsFuture) { article, tags in
            
            let context = AdminArticleContext(tabTitle: "MyBlog>Admin",
                                              pageTitle: "Creation Article",
                                              tags: tags,
                                              article: article,
                                              isEditing: true)
            return try req.view().render("admin/article", context)
        }
    }
    
    // POST route for blog.com/admin/articles/articleID/edit
    func editArticlePostHandler(_ req: Request, articleUpdated: AdminArticleData) throws -> Future<Response> {
        
        let user = try req.requireAuthenticated(User.self)
        
        return try req.parameters.next(Article.self).flatMap(to: Response.self) { article in
            article.authorID = try user.requireID()
            article.slugURL = articleUpdated.slugURL
            article.title = articleUpdated.title
            article.content = articleUpdated.content
            article.snippet = articleUpdated.snippet
            //article.editionDate = Date()
            //article.published = articleUpdated.published ?? false
            
            return article.update(on: req).flatMap(to: Response.self) { article in
                
                let tags = article.tags
                
                return tags.detachAll(on: req).flatMap(to: Response.self) { _ in
                    
                    var futures = [Future<ArticleTagPivot>]()
                    
                    if let tags = articleUpdated.tags {
                        for tag in tags {
                            let attachTagFuture = Tag.query(on: req).filter(\.name == tag).first().flatMap(to: ArticleTagPivot.self) { futureTag in
                                guard let futureTag = futureTag else { fatalError("the tag should exist") }
                                return article.tags.attach(futureTag, on: req)
                            }
                            futures.append(attachTagFuture)
                        }
                    }
                    return futures.flatten(on: req).transform(to: req.redirect(to: "/admin/articles"))
                }
            }
        }
    }
    
    // route for blog.com/admin/articles/articleID/delete
    func deleteArticlePostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Article.self).delete(on: req).transform(to: req.redirect(to: "/admin/articles"))
    }
    
    // MARK: - Routes for Txt file (download and creation)
    
    // route for blog.com/admin/articles/articleID/download
    func downloadArticleHandler(_ req: Request) throws -> Future<Response> {
        let article = try req.parameters.next(Article.self)
        return article.map(to: Response.self) { article in
            let filename = article.slugURL + ".txt"
            var textFile = "--title--\r\n" + "\(article.title)\r\n"
            textFile = textFile + "--slugURL--\r\n" + "\(article.slugURL)\r\n"
            textFile = textFile + "--snippet--\r\n" + "\(article.snippet)\r\n"
            textFile = textFile + "--author--\r\n" + "\(article.snippet)\r\n"
            textFile = textFile + "--created--\r\n" + "\(article.snippet)\r\n"
            textFile = textFile + "--edited--\r\n" + "\(article.snippet)\r\n"
            textFile = textFile + "--published--\r\n" + "\(article.snippet)\r\n"
            textFile = textFile + "--mainPicture--\r\n" + "\(article.snippet)\r\n"
            textFile = textFile + "--content--\r\n" + "\(article.content)"
            
            
            let data = textFile.convertToData()
            let response = req.response(data, as: .plainText)
            response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
            return response
        }
    }
    
    // route for blog.com/admin/articles/download
    func downloadAllArticlesHandler(_ req: Request) throws -> Future<Response> {
        
        return Article.query(on: req).all().map(to: Response.self) { articles in
            var resultText = ""
            for article in articles {
                var textFile = "--title--\r\n" + "\(article.title)\r\n"
                textFile = textFile + "--slugURL--\r\n" + "\(article.slugURL)\r\n"
                textFile = textFile + "--snippet--\r\n" + "\(article.snippet)\r\n"
                textFile = textFile + "--author--\r\n" + "\(article.snippet)\r\n"
                textFile = textFile + "--created--\r\n" + "\(article.snippet)\r\n"
                textFile = textFile + "--edited--\r\n" + "\(article.snippet)\r\n"
                textFile = textFile + "--published--\r\n" + "\(article.snippet)\r\n"
                textFile = textFile + "--mainPicture--\r\n" + "\(article.snippet)\r\n"
                textFile = textFile + "--content--\r\n" + "\(article.content)"
                resultText = resultText + textFile
            }
            
            let data = resultText.convertToData()
            let response = req.response(data, as: .plainText)
            response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"articles.txt\"")
            return response
        }
    }
    
    // route for blog.com/admin/articles/createFromTxt
    func createArticleFromTxtHandler(_ req: Request, fileData: AdminTextArticleData) throws -> Future<Response> {
        
        let txtData = fileData.file.data
        guard var articleTxt = String(data: txtData, encoding: .utf8) else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        
        articleTxt = articleTxt.replacingOccurrences(of: "\r", with: "")
        articleTxt = articleTxt.replacingOccurrences(of: "\n", with: "")
        
        let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--author", "--snippet--", "--slugURL--", "--title--"]
        var articleDictionary: [String: String] = [String: String]()
        for identifier in identifiers {
            let components = articleTxt.components(separatedBy: identifier)
            if let restOfComponents = components.first,
                let component = components.last {
                articleTxt = restOfComponents
                articleDictionary[identifier] = component
            }
        }
        
        guard let title = articleDictionary["--title--"],
            let slugURL = articleDictionary["--slugURL--"],
            let snippet = articleDictionary["--snippet--"],
            let author = articleDictionary["--author--"],
            let created = articleDictionary["--created--"],
            let mainPicture = articleDictionary["--mainPicture--"],
            let content = articleDictionary["--content--"] else {
                return req.redirect(to: "/admin/articles/")
        }
        
        var published: Date?
        if let publishedDateString = articleDictionary["--published--"] {
            published =
        }
        var edited: Date? = articleDictionary["--edited--"]
            
        let user = try req.requireAuthenticated(User.self)
            
        let newArticleFuture = Article(title: title,
                                           slugURL: slugURL,
                                           content: content,
                                           snippet: snippet,
                                           authorID: try user.requireID(),
                                           created: created,
                                           edited: edited,
                                           published: published,
                                           mainPicture: mainPicture).save(on: req)
            .save(on: req).map(to: Response.self) { article in
                guard let articleID = article.id else {
                    throw Abort(.internalServerError)
                }
                
                return req.redirect(to: "/admin/articles/\(articleID)/edit")
            }
        } 
    }
    
    // route for blog.com/admin/articles/createAllFromTxt
    func createAllArticlesFromTxtHandler(req: Request, fileTextData: AdminTextArticleData) throws -> Future<Response> {
        
        let txtData = fileTextData.file.data
        guard var text = String(data: txtData, encoding: .utf8) else {
            throw Abort(.internalServerError)
        }
        
        text = text.replacingOccurrences(of: "\r", with: "")
        text = text.replacingOccurrences(of: "\n", with: "")
        
        // Split txt file with separator between articles
        let separator = Article.separator
        var articles = text.components(separatedBy: separator)
        articles = articles.filter { article -> Bool in
            return article != ""
        }
        
        
        var articlesFuture = [Future<Article>]()
        
        let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--author", "--snippet--", "--slugURL--", "--title--"]
        var articleDictionary: [String: String] = [String: String]()
        for article in articles {
            var newArticle: String = article
            for identifier in identifiers {
                let articleComponents = newArticle.components(separatedBy: identifier)
                guard let restOfArticle = articleComponents.first,
                    let articleComponent = articleComponents.last else {
                        throw Abort(.internalServerError)
                }
                newArticle = restOfArticle
                articleDictionary[identifier] = articleComponent
            }
            
            if let title = articleDictionary["--title--"],
                let slugURL = articleDictionary["--slugURL--"],
                let snippet = articleDictionary["--snippet--"],
                let author = articleDictionary["--author--"],
                let created = articleDictionary["--created--"],
                let edited = articleDictionary["--edited--"],
                let published = articleDictionary["--published--"],
                let mainPicture = articleDictionary["--mainPicture--"],
                let content = articleDictionary["--content--"] {
            
                let user = try req.requireAuthenticated(User.self)
            
                let newArticleFuture = Article(title: title,
                                           slugURL: slugURL,
                                           content: content,
                                           snippet: snippet,
                                           authorID: try user.requireID(),
                                           creationDate: created,
                                           edited: edited,
                                           published: published,
                                           mainPicture: mainPicture).save(on: req)
            articlesFuture.append(newArticleFuture)
        }
        
        return articlesFuture.flatten(on: req).transform(to: req.redirect(to: "/admin/articles"))
        
    }
    
}

// MARK: - Struct Articles


struct AdminArticlesContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let articles: [Article.Leaffed]
    let olderPagePath: String?
    let newerPagePath: String?
}

struct AdminArticleContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
    let article: Article?
    let isEditing: Bool
}

struct AdminArticleData: Content {
    var title: String
    var slugURL: String
    var content: String
    var snippet: String
    var tags: [String]?
    var mainPicture: String
    var published: Bool?
}

struct AdminTextArticleData: Content {
    let file: File
}
