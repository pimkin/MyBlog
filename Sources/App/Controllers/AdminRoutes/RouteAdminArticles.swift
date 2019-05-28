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
        
        return try req.parameters.next(Article.self).flatMap(to: View.self) { article in
            return try article.leaf(on: req).flatMap(to: View.self) { leaffedArticle in
                return Tag.query(on: req).all().flatMap(to: View.self) { tags in
            
                    let context = AdminArticleContext(tabTitle: "MyBlog>Admin",
                                              pageTitle: "Creation Article",
                                              tags: tags,
                                              article: leaffedArticle,
                                              isEditing: true)
                    return try req.view().render("admin/article", context)
                }
            }
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
            article.mainPicture = articleUpdated.mainPicture
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MM/dd/yyyy hh:mma"
            if let createdString = articleUpdated.created,
                let created = dateFormatter.date(from: createdString) {
                article.created = created
            } else {
                article.created = Date()
            }
            
            if let publishedString = articleUpdated.published {
                article.published = dateFormatter.date(from: publishedString)
            }
            
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
    
        let futureArticle = try req.parameters.next(Article.self)
        let textinator = Textinator()
        return try textinator.textFileFrom(futureArticle: futureArticle, on: req)
    
    }
    
    // route for blog.com/admin/articles/download
    func downloadAllArticlesHandler(_ req: Request) throws -> Future<Response> {
        
        let textinator = Textinator()
        return try textinator.textFileFromAllArticles(on: req)
        
    }
    
    // route for blog.com/admin/articles/createFromTxt
    func createArticleFromTxtHandler(_ req: Request, data: AdminTextArticleData) throws -> Future<Response> {
        
        let file = data.file
        let textinator = Textinator()
        
        return try textinator.articlesFromFile(file: file, on: req).transform(to: req.redirect(to: "/admin/articles/"))
    }
    
    // route for blog.com/admin/articles/createAllFromTxt
    func createAllArticlesFromTxtHandler(req: Request, data: AdminTextArticleData) throws -> Future<Response> {
        
        let file = data.file
        let textinator = Textinator()
        
        return try textinator.articlesFromFile(file: file, on: req).transform(to: req.redirect(to: "/admin/articles/"))
        
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
    let article: Article.Leaffed?
    let isEditing: Bool
}

struct AdminArticleData: Content {
    var title: String
    var slugURL: String
    var content: String
    var snippet: String
    var tags: [String]?
    var mainPicture: String?
    var created: String?
    var published: String?
}

struct AdminTextArticleData: Content {
    let file: File
}
