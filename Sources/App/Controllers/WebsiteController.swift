import Vapor
import Leaf
import Authentication
import FluentSQL


final class WebsiteController: RouteCollection {
    
    func boot(router: Router) throws {
        
        let authSessRoutes = router.grouped(User.authSessionsMiddleware())
        
        // route blog.com/ and blog.com/page/pageNumber
        //  -> the front page of the blog with the list of articles
        authSessRoutes.get("/", use: getIndexHandler)
        authSessRoutes.get("page", Int.parameter, use: getIndexPageHandler)
        
        // route blog.com/articleSlugURL
        //  -> to access an article by its slugURL
        authSessRoutes.get(String.parameter, use: getArticleHandler)
        
        // route blog.com/tag/tagName and blog.com/tag/tagName/page/pageNumber
        //  -> to access to the articles with the same tag
        authSessRoutes.get("tag", String.parameter, use: getTagHandler)
        authSessRoutes.get("tag", String.parameter, "page",  Int.parameter, use: getTagPageHandler)
        
        // route blog.com/user/userName and blog.com/user/userName/page/pageNumber
        //  -> to access to the articles from a user
        authSessRoutes.get("user", String.parameter, use: getUserHandler)
        authSessRoutes.get("user", String.parameter, "page", Int.parameter, use: getUserPageHandler)
        
        // route to log in and log out
        authSessRoutes.get("login", use: getLoginHandler)
        authSessRoutes.post(LoginData.self, at: "login", use: loginPostHandler)
        authSessRoutes.get("logout", use: logoutHandler)
        
        // route to get an image saved on the server
        //  (see the admin section for the route about uploading an image)
        authSessRoutes.get("Images", String.parameter, use: getImageHandler)
        
        
        
        authSessRoutes.get("about", use: aboutHandler)
        //authSessRoutes.get("archives", use: archivesHandler)
        //authSessRoutes.get("contact", use: contactHandler)

    }
    
    // MARK: Index Routes
    
    // route blog.com/
    //  -> the front page of the blog with the list of articles
    func getIndexHandler(_ req: Request) throws -> Future<View> {
        
        let searchQuery = req.query[String.self, at:"search"]
        
        var paginator: Paginator
        if let searchTerm = searchQuery {
            paginator = Paginator(WithPageNumber: 1, forType: .search(searchTerm: searchTerm))
        } else {
            paginator = Paginator(WithPageNumber: 1, forType: .index)
        }
        
        let articlesFuture = Article.query(on: req).group(.and) { and in
            if let searchTerm = searchQuery {
                and.filter(\.title ~~ searchTerm)
            }}
            .range(paginator.rangePlusOne).sort(\.created, .descending).all()
        
        return try makeView(on: req, with: articlesFuture, and: paginator)
    }
    
    // route blog.com/page/pageNumber
    //  -> the front page of the blog with the list of articles (pagination)
    func getIndexPageHandler(req: Request) throws -> Future<View> {
        
        let pageNumber = try req.parameters.next(Int.self)
        let searchQuery = req.query[String.self, at:"search"]
        
        var paginator: Paginator
        if let searchTerm = searchQuery {
            paginator = Paginator(WithPageNumber: pageNumber,
                                  forType: .search(searchTerm: searchTerm))
        } else {
            paginator = Paginator(WithPageNumber: pageNumber,
                                  forType: .index)
        }
        
        
        let articlesFuture = Article.query(on: req).group(.and) { and in
            if let searchTerm = searchQuery {
                and.filter(\.title ~~ searchTerm)
            }}
            .range(paginator.rangePlusOne).sort(\.created, .descending).all()
        
        return try makeView(on: req, with: articlesFuture, and: paginator)
    }
    
    // MARK: Article Route

    // route blog.com/articleSlugURL
    //  -> to access an article by its slugURL
    func getArticleHandler(_ req: Request) throws -> Future<View> {
        let slugURL = try req.parameters.next(String.self)
        return Article.query(on: req).filter(\.slugURL == slugURL).first().flatMap(to: View.self) { article in
            
            let user = try req.authenticated(User.self)

            guard let article = article else {
                return Tag.query(on: req).all().flatMap(to: View.self) { tags in
                    let erreurContext = ErreurContext(user: user?.convertToPublic(),
                                                  tabTitle: "MyBlog : Page not found",
                                                  pageTitle: "Page not found",
                                                  tags: tags)
                
                    return try req.view().render("error", erreurContext)
                }
            }
            
            let tagsFuture = Tag.query(on: req).all()
            let articleFuture = try article.leaf(on: req)
            
            return flatMap(to: View.self, tagsFuture, articleFuture) { tags, leaffedArticle in
                
                let user = try req.authenticated(User.self)
                
                let context = ArticleContext(user: user?.convertToPublic(),
                                             tabTitle: "MyBlog : " + leaffedArticle.title,
                                             pageTitle: leaffedArticle.title,
                                             tags: tags,
                                             article: leaffedArticle)
                
                return try req.view().render("article", context)
            }
        }
    }
    
    // MARK: Tag Routes

    // route blog.com/tag/tagName
    //  -> to access to the articles with the same tag
    func getTagHandler(_ req: Request) throws -> Future<View> {
        let tagName = try req.parameters.next(String.self)
        
        return Tag.query(on: req).filter(\.name == tagName).first().flatMap(to: View.self) { fetchedTag in
            guard let tag = fetchedTag else {
                throw Abort(.badRequest)
            }
            
            let paginator = Paginator(WithPageNumber: 1,
                                      forType: .tag(tagName: tag.name))
            
            let articlesFuture = try tag.articles.query(on: req).range(paginator.rangePlusOne).sort(\.created, .descending).all()
                
            return try self.makeView(on: req, with: articlesFuture, and: paginator)
        }
    }
    
    // route blog.com/tag/tagName/page/pageNumber
    //  -> to access to the articles with the same tag (pagination)
    func getTagPageHandler(req: Request) throws -> Future<View> {
        
        let tagName = try req.parameters.next(String.self)
        let pageNumber = try req.parameters.next(Int.self)
        
        return Tag.query(on: req).filter(\.name == tagName).first().flatMap(to: View.self) { fetchedTag in
            guard let tag = fetchedTag else {
                throw Abort(.badRequest)
            }
            
            let paginator = Paginator(WithPageNumber: pageNumber,
                                      forType: .tag(tagName: tag.name))
            
            let articlesFuture = try tag.articles.query(on: req).range(paginator.rangePlusOne).sort(\.created, .descending).all()
            
            return try self.makeView(on: req, with: articlesFuture, and: paginator)
        }
    }
    
    // MARK: User Routes

    // route blog.com/user/userName
    //  -> to access to the articles from a user
    func getUserHandler(req: Request) throws -> Future<View> {
        
        let userName = try req.parameters.next(String.self)
        
        return User.query(on: req).filter(\.username == userName).first().flatMap(to: View.self) { fetchedUser in
            guard let user = fetchedUser else {
                throw Abort(.badRequest)
            }
            
            let paginator = Paginator(WithPageNumber: 1,
                                      forType: .user(username: user.username))
            
            let articlesFuture = try user.articles.query(on: req).range(paginator.rangePlusOne).sort(\.created, .descending).all()
            
            return try self.makeView(on: req, with: articlesFuture, and: paginator)
        }
    }
    
    // route blog.com/user/userName/page/pageNumber
    //  -> to access to the articles from a user (pagination)
    func getUserPageHandler(req: Request) throws -> Future<View> {
        
        let userName = try req.parameters.next(String.self)
        let pageNumber = try req.parameters.next(Int.self)
        
        return User.query(on: req).filter(\.username == userName).first().flatMap(to: View.self) { fetchedUser in
            guard let user = fetchedUser else {
                throw Abort(.badRequest)
            }
            
            let paginator = Paginator(WithPageNumber: pageNumber,
                                      forType: .user(username: user.username))
            
            let articlesFuture = try user.articles.query(on: req).range(paginator.rangePlusOne).sort(\.created, .descending).all()
            
            return try self.makeView(on: req, with: articlesFuture, and: paginator)
        }
    }
    
    // MARK: About/Archives/Contact
    
    func aboutHandler(_ req: Request) throws -> Future<View> {
        let user = try req.authenticated(User.self)
        let context = AboutContext(user: user?.convertToPublic(),
                                   tabTitle: "MyBlog - About",
                                   pageTitle: "About MyBlog")
        return try req.view().render("about", context)
    }
    
//    func archivesHandler(_ req: Request) throws -> Future<View> {
//        let user = try req.authenticated(User.self)
//        let context = ArchivesContext(user: user?.convertToPublic(),
//                                   tabTitle: "MyBlog - Archives",
//                                   pageTitle: "Archives MyBlog")
//        return try req.view().render("archives", context)
//    }
//    
//    func contactHandler(_ req: Request) throws -> Future<View> {
//        let user = try req.authenticated(User.self)
//        let context = ContactContext(user: user?.convertToPublic(),
//                                   tabTitle: "MyBlog - Contact",
//                                   pageTitle: "Contact MyBlog")
//        return try req.view().render("contact", context)
//    }
    
    
    // MARK: Login/logout/register Routes

    
    // route to log in
    func getLoginHandler(_ req: Request) throws -> Future<View> {
        
        return Tag.query(on: req).all().flatMap(to: View.self) { tags in
            
            let user = try req.authenticated(User.self)
            
            let context = LoginContext(user: user?.convertToPublic(),
                                          tabTitle: "MyBlog - Login",
                                          pageTitle: "Login",
                                          tags: tags)
            
            return try req.view().render("login", context)
        }
    }
    // POST route to login
    func loginPostHandler( _ req: Request, loginData: LoginData) throws -> Future<Response> {
        return User.authenticate(username: loginData.username,
                                 password: loginData.password,
                                 using: BCryptDigest(),
                                 on: req)
            .map(to: Response.self) { author in
                guard let author = author else {
                    return req.redirect(to: "/login")
                }
                try req.authenticateSession(author)
                return req.redirect(to: "/admin/")
        }
    }
    
    // route to log out
    func logoutHandler(_ req: Request) throws -> Response {
        try req.unauthenticateSession(User.self)
        return req.redirect(to: "/")
    }
    
    
    
    
    // MARK: - Image Route
    
    // Route to get an image (the filename is in the url)
    func getImageHandler(_ req: Request) throws -> Future<Response> {
        let filename = try req.parameters.next(String.self)
        let workPath = DirectoryConfig.detect().workDir
        let imagePath = workPath + "Images/" + filename
        
        return try req.streamFile(at: imagePath)
    }
    
    
    // MARK: - construct methods
    //  used by all the other route functions to display the articles
    func makeView(on req: Request, with articlesFuture: Future<[Article]>, and paginator: Paginator) throws -> Future<View> {
        
        let tagsFuture = Tag.query(on: req).all()
        
        return flatMap(to: View.self, tagsFuture, articlesFuture) { tags, fetchedArticles in
            
            return try fetchedArticles.leaf(on: req).flatMap(to: View.self) { fetchedLeaffedArticles in
                
                var leaffedArticles = fetchedLeaffedArticles
                //
                var olderPagePath: String? = nil
                if fetchedLeaffedArticles.count > paginator.articlesPerPage {
                    olderPagePath = paginator.olderPagePath
                    leaffedArticles.removeLast()
                }
                
                let user = try req.authenticated(User.self)
                
                let context = ArticlesContext(user: user?.convertToPublic(),
                                              tabTitle: paginator.tabTitle,
                                              pageTitle: paginator.pageTitle,
                                              tags: tags,
                                              articles: leaffedArticles,
                                              olderPagePath: olderPagePath,
                                              newerPagePath: paginator.newerPagePath)
                
                return try req.view().render("articles", context)
            }
        }
    }
    
    
}

// MARK: - Structs pour Blog

struct ArticlesContext: Encodable {
    let user: User.Public?
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
    let articles: [Article.Leaffed]
    let olderPagePath: String?
    let newerPagePath: String?
}

struct ArticleContext: Encodable {
    let user: User.Public?
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
    let article: Article.Leaffed
}

struct ErreurContext: Encodable {
    let user: User.Public?
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
}

struct AboutContext: Encodable {
    let user: User.Public?
    let tabTitle: String
    let pageTitle: String
}

//struct ArchivesContext: Encodable {
//    let user: User.Public?
//    let tabTitle: String
//    let pageTitle: String
//}
//
//struct ContactContext: Encodable {
//    let user: User.Public?
//    let tabTitle: String
//    let pageTitle: String
//}

struct LoginContext: Encodable {
    let user: User.Public?
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
}

struct LoginData: Content {
    var username: String
    var password: String
}

