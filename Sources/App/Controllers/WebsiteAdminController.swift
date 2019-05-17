import Vapor
import Authentication
import FluentSQL

struct WebsiteAdminController: RouteCollection {
    
    let imageFolder = "ProfilePictures/"
    
    func boot(router: Router) throws {
        
        let authSessRoutes = router.grouped(User.authSessionsMiddleware())
        let protectedRoutes = authSessRoutes.grouped(RedirectMiddleware(A: User.self, path: "/login"))
        let adminRoutes = protectedRoutes.grouped("admin")
        
        adminRoutes.get("/", use: indexHandler)
        
        
        // articles routes
        adminRoutes.get("articles", use: allArticlesHandler)
        adminRoutes.get("articles", "page", Int.parameter, use: allArticlesPageHandler)
        adminRoutes.get("articles", "create", use: createArticleHandler)
        adminRoutes.post(AdminArticleData.self, at:"articles", "create", use: createArticlePostHandler)
        adminRoutes.get("articles", Article.parameter, "edit", use: editArticleHandler)
        adminRoutes.post(AdminArticleData.self, at:"articles", Article.parameter, "edit", use: editArticlePostHandler)
        adminRoutes.post("articles", Article.parameter, "delete", use: deleteArticlePostHandler)
        
        // tags routes
        adminRoutes.get("tags", use: allTagsHandler)
        adminRoutes.get("tags", "page", Int.parameter, use: allTagsPageHandler)
        adminRoutes.get("tags", "create", use: createTagHandler)
        adminRoutes.post(AdminTagData.self, at:"tags", "create", use: createTagPostHandler)
        adminRoutes.get("tags", Tag.parameter, "edit", use: editTagHandler)
        adminRoutes.post(AdminTagData.self, at:"tags", Tag.parameter, "edit", use: editTagPostHandler)
        adminRoutes.post("tags", Tag.parameter, "delete", use: deleteTagPostHandler)
        
        // users routes
        adminRoutes.get("users", use: allUsersHandler)
        adminRoutes.get("users", "page", Int.parameter, use: allUsersPageHandler)
        adminRoutes.get("users", User.parameter, "edit", use: editUserHandler)
        adminRoutes.post(AdminUserData.self, at:"users", User.parameter, "edit", use: editUserPostHandler)
        adminRoutes.post("users", User.parameter, "delete", use: deleteUserPostHandler)
        
        // register routes
        adminRoutes.get("users", "register", use: registerHandler)
        adminRoutes.post(AdminRegisterData.self, at:"users", "register", use: registerPostHandler)
        
        // profilePictures routes
        //        adminRoutes.get("users", User.parameter, "profilePicture", use: getUsersProfilePictureHandler)
        //        adminRoutes.get("users", User.parameter, "addProfilePicture", use: addProfilePictureHandler)
        //        adminRoutes.post("users", User.parameter, "addProfilePicture", use: addProfilePicturePostHandler)
    }
    
    // Mark: - Index Route
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        let context = AdminIndexContext(tabTitle: "MyBlog>Admin",
                                        pageTitle: "Section Administration")
        return try req.view().render("admin/index", context)
    }
    
    // Mark: - Article Routes
    
    func allArticlesHandler(_ req: Request) throws -> Future<View> {
        
        let searchTerm = req.query[String.self, at:"search"]
        let paginator = AdminPaginator(WithPageNumber: 1, forType: .articles(searchTerm: searchTerm))
        
        return Article.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.title ~~ term)
            }
            
            }.range(paginator.rangePlusOne).all()
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
    
    func allArticlesPageHandler(_ req: Request) throws -> Future<View> {
        let pageNumber = try req.parameters.next(Int.self)
        let searchTerm = req.query[String.self, at:"search"]
        
        let paginator = AdminPaginator(WithPageNumber: pageNumber, forType: .articles(searchTerm: searchTerm))
        
        return Article.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.title ~~ term)
            }
            
            }.range(paginator.rangePlusOne).all()
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
    
    func createArticlePostHandler(_ req: Request, articleData: AdminArticleData) throws -> Future<Response> {
        let author = try req.requireAuthenticated(User.self)
        let article = Article(title: articleData.title,
                              slugURL: articleData.slugURL,
                              content: articleData.content,
                              snippet: articleData.snippet,
                              authorID: try author.requireID(),
                              creationDate: Date(),
                              published: articleData.published ?? false)
        
        let articleFuture = article.save(on: req)
        let tagFuture = Tag.query(on: req).filter(\.name == articleData.tag).first()
        
        return flatMap(to: Response.self, articleFuture, tagFuture) { article, tag in
            guard let tag = tag else { fatalError("the tag should exist") }
            return article.tags.attach(tag, on: req).transform(to: req.redirect(to: "/admin/articles"))
        }
    }
    
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
    
    func editArticlePostHandler(_ req: Request, articleUpdated: AdminArticleData) throws -> Future<Response> {
        
        return Tag.query(on: req).filter(\.name == articleUpdated.tag).first().flatMap(to: Response.self) { tag in
            
            guard let tag = tag else { fatalError("the tag should exist") }
            
            let user = try req.requireAuthenticated(User.self)
            
            return try req.parameters.next(Article.self).flatMap(to: Response.self) { article in
                article.authorID = try user.requireID()
                article.slugURL = articleUpdated.slugURL
                article.title = articleUpdated.title
                article.content = articleUpdated.content
                article.snippet = articleUpdated.snippet
                article.editionDate = Date()
                article.published = articleUpdated.published ?? false
                
                let articleFuture = article.update(on: req)
                let detachFuture = article.tags.detachAll(on: req)
                let attachFuture = article.tags.attach(tag, on: req)
                
                
                return map(to: Response.self, articleFuture, detachFuture, attachFuture) { _, _, _ in
                    return req.redirect(to: "/admin/articles")
                    
                }
            }
        }
    }
    
    func deleteArticlePostHandler(_ req: Request) throws -> Future<Response> {
        // Obligé de mettre /admin/articles plutôt que articles
        // Peut-être parce que la requete vient de la page admin/articles et se recharge simplement,
        // Du coup ça bug
        return try req.parameters.next(Article.self).delete(on: req).transform(to: req.redirect(to: "/admin/articles"))
    }
    
    // MARK:- Tag Routes
    
    func allTagsHandler(_ req: Request) throws -> Future<View> {
        let searchTerm = req.query[String.self, at:"search"]
        
        let paginator = AdminPaginator(WithPageNumber: 1, forType: .tags(searchTerm: searchTerm))
        
        return Tag.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.name == term)
            }
            
            }.range(paginator.rangePlusOne).all()
            .flatMap(to: View.self) { fetchedTags in
                
                var tags = fetchedTags
                
                var olderPagePath: String?
                if fetchedTags.count > paginator.articlesPerPage {
                    tags.removeLast()
                    olderPagePath = paginator.olderPagePath
                }
                
                let context = AdminTagsContext(tabTitle: paginator.tabTitle,
                                               pageTitle: paginator.pageTitle,
                                               tags: tags,
                                               olderPagePath: olderPagePath,
                                               newerPagePath: paginator.newerPagePath)
                return try req.view().render("admin/tags", context)
                
        }
    }
    
    func allTagsPageHandler(_ req: Request) throws -> Future<View> {
        let searchTerm = req.query[String.self, at:"search"]
        let pageNumber = try req.parameters.next(Int.self)
        
        let paginator = AdminPaginator(WithPageNumber: pageNumber, forType: .tags(searchTerm: searchTerm))
        
        return Tag.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.name == term)
            }
            
            }.range(paginator.rangePlusOne).all()
            .flatMap(to: View.self) { fetchedTags in
                
                var tags = fetchedTags
                
                var olderPagePath: String?
                if fetchedTags.count > paginator.articlesPerPage {
                    tags.removeLast()
                    olderPagePath = paginator.olderPagePath
                }
                
                let context = AdminTagsContext(tabTitle: paginator.tabTitle,
                                               pageTitle: paginator.pageTitle,
                                               tags: tags,
                                               olderPagePath: olderPagePath,
                                               newerPagePath: paginator.newerPagePath)
                return try req.view().render("admin/tags", context)
        }
    }
    
    
    
    func createTagHandler(_ req: Request) throws -> Future<View> {
        let context = AdminTagContext(tabTitle: "MyBlog>Admin : Create a New Tag",
                                      pageTitle: "Créer un nouveau Tag",
                                      tag: nil,
                                      isEditing: false)
        
        return try req.view().render("admin/tag", context)
    }
    
    func createTagPostHandler(_ req:Request, data: AdminTagData) throws -> Future<Response> {
        return Tag(name: data.name, description: data.description).save(on: req).transform(to: req.redirect(to: "/admin/tags"))
    }
    
    func editTagHandler(_ req: Request) throws -> Future<View> {
        
        let futureTag = try req.parameters.next(Tag.self)
        
        return futureTag.flatMap(to: View.self) { tag in
            let context = AdminTagContext(tabTitle: "MyBlog>Admin : Edit a Tag",
                                          pageTitle: "Edition d'un tag",
                                          tag: tag,
                                          isEditing: true)
            
            return try req.view().render("admin/tag", context)
        }
    }
    
    func editTagPostHandler(_ req: Request, data: AdminTagData) throws -> Future<Response> {
        let futureTag = try req.parameters.next(Tag.self)
        
        return futureTag.flatMap(to: Response.self) { tag in
            
            tag.name = data.name
            tag.description = data.description
            
            return tag.update(on: req).transform(to: req.redirect(to: "/admin/tags"))
        }
    }
    
    func deleteTagPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Tag.self).flatMap(to: Response.self) { tag in
            return tag.delete(on: req).transform(to: req.redirect(to: "/admin/tags"))
        }
    }
    
    // MARK:- Users Routes
    
    func allUsersHandler(_ req: Request) throws -> Future<View> {
        let searchTerm = req.query[String.self, at:"search"]
        
        let paginator = AdminPaginator(WithPageNumber: 1, forType: .users(searchTerm: searchTerm))
        
        return User.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.username == term)
            }
            
            }.range(paginator.rangePlusOne).all()
            .flatMap(to: View.self) { fetchedUsers in
                
                var publicUsers = fetchedUsers.map { $0.convertToPublic() }

                var olderPagePath: String?
                if fetchedUsers.count > paginator.articlesPerPage {
                    publicUsers.removeLast()
                    olderPagePath = paginator.olderPagePath
                }
                
                let context = AdminUsersContext(tabTitle: paginator.tabTitle,
                                               pageTitle: paginator.pageTitle,
                                               users: publicUsers,
                                               olderPagePath: olderPagePath,
                                               newerPagePath: paginator.newerPagePath)
                return try req.view().render("admin/users", context)
        }
    }
    
    func allUsersPageHandler(_ req: Request) throws -> Future<View> {
        let searchTerm = req.query[String.self, at:"search"]
        let pageNumber = try req.parameters.next(Int.self)
        
        let paginator = AdminPaginator(WithPageNumber: pageNumber, forType: .users(searchTerm: searchTerm))
        
        return User.query(on: req).group(.or) { orGroup in
            
            if let term = searchTerm {
                orGroup.filter(\.username == term)
            }
            
            }.range(paginator.rangePlusOne).all()
            .flatMap(to: View.self) { fetchedUsers in
                
                var publicUsers = fetchedUsers.map { $0.convertToPublic() }
                
                var olderPagePath: String?
                if fetchedUsers.count > paginator.articlesPerPage {
                    publicUsers.removeLast()
                    olderPagePath = paginator.olderPagePath
                }
                
                let context = AdminUsersContext(tabTitle: paginator.tabTitle,
                                                pageTitle: paginator.pageTitle,
                                                users: publicUsers,
                                                olderPagePath: olderPagePath,
                                                newerPagePath: paginator.newerPagePath)
                return try req.view().render("admin/users", context)
        }
    }
    
    func editUserHandler(_ req: Request) throws -> Future<View> {
        let futureUser = try req.parameters.next(User.self)
        
        return futureUser.flatMap(to: View.self) { user in
            let context = AdminUserContext(title: "MyBlog>Admin",
                                           user: user.convertToPublic())
            return try req.view().render("admin/user", context)
        }
    }
    
    func editUserPostHandler(_ req: Request, data: AdminUserData) throws -> Future<Response> {
        let futureProfile = try req.parameters.next(User.self)
        
        return futureProfile.flatMap(to: Response.self) { profile in
            profile.name = data.name
            profile.username = data.username
            
            return futureProfile.update(on: req).transform(to: req.redirect(to: "/admin/users"))
        }
    }
    
    func deleteUserPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(User.self).flatMap(to: Response.self) { user in
            return user.delete(on: req).transform(to: req.redirect(to: "/admin/users"))
        }
    }
    
    /*
     func getUsersProfilePictureHandler(_ req: Request) throws -> Future<Response> {
     return try req.parameters.next(User.self).flatMap(to: Response.self) { user in
     guard let filename = user.pictureProfile else {
     throw Abort(.notFound)
     }
     let path = try req.make(DirectoryConfig.self).workDir + self.imageFolder + filename
     return try req.streamFile(at: path)
     }
     }
     
     func addProfilePictureHandler(_ req: Request) throws -> Future<View> {
     return try req.parameters.next(User.self).flatMap { user in
     try req.view().render("admin/addProfilePicture", ["title": "Add Profile Picture", "username": user.name])
     }
     }
     
     func addProfilePicturePostHandler(_ req: Request) throws -> Future<Response> {
     return try flatMap(to: Response.self,
     req.parameters.next(User.self),
     req.content.decode(ImageUploadData.self)) { user, imageData in
     
     let workPath = try req.make(DirectoryConfig.self).workDir
     let name = try "\(user.requireID())-\(UUID().uuidString).jpg"
     let path = workPath + self.imageFolder + name
     
     FileManager().createFile(atPath: path,
     contents: imageData.picture,
     attributes: nil)
     user.pictureProfile = name
     // let redirect = try req.redirect(to: "/users/\(user.requireID())")
     let redirect = req.redirect(to: "/admin/users/")
     return user.save(on: req).transform(to: redirect)
     }
     }
     */
    
    // MARK: Register route
    
    func registerHandler(_ req: Request) throws -> Future<View> {
        
        return Tag.query(on: req).all().flatMap(to: View.self) { tags in
            
            let user = try req.authenticated(User.self)
            
            var context = RegisterContext(user: user?.convertToPublic(),
                                          tabTitle: "MyBlog - Register",
                                          pageTitle: "Register",
                                          tags: tags,
                                          message: nil)
            if let message = req.query[String.self, at: "message"] {
                context.message = message
            }
            
            return try req.view().render("admin/register", context)
        }
    }
    
    func registerPostHandler(_ req: Request, data: AdminRegisterData) throws -> Future<Response> {
        do {
            try data.validate()
        } catch (let error) {
            let redirect: String
            if let error = error as? ValidationError,
                let message = error.reason.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                redirect = "/admin/users/register?message=\(message)"
            } else {
                redirect = "/admin/users/register?message=Unknown+error"
            }
            return req.future(req.redirect(to: redirect))
        }
        
        let hashedPassword = try BCrypt.hash(data.password)
        let user = User(name: data.name,
                        username: data.username,
                        password: hashedPassword)
        return user.save(on: req).map(to: Response.self) { user in
            try req.authenticateSession(user)
            return req.redirect(to: "/admin/users")
        }
    }
    
    
    
}

// MARK: - Struct Index

struct AdminIndexContext: Encodable {
    let tabTitle: String
    let pageTitle: String
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
    var tag: String
    var published: Bool?
}

// MARK: - Struct Tags

struct AdminTagsContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
    let olderPagePath: String?
    let newerPagePath: String?
}

struct AdminTagContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let tag: Tag?
    var isEditing: Bool
}

struct AdminTagData: Content {
    let name: String
    let description: String
}

// MARK: - Struct Users

struct AdminUsersContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let users: [User.Public]
    let olderPagePath: String?
    let newerPagePath: String?
}

struct AdminUserContext: Encodable {
    let title: String
    let user: User.Public
}

struct AdminUserData: Content {
    let name: String
    let username: String
    let password: String
}

struct ImageUploadData: Content {
    var picture: Data
}

// MARK: - Register structs

struct AdminRegisterContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
    var message: String?
}

struct AdminRegisterData: Content {
    let name: String
    let username: String
    let password: String
    let confirmPassword: String
}


extension AdminRegisterData: Validatable, Reflectable {
    static func validations() throws -> Validations<AdminRegisterData> {
        var validations = Validations(AdminRegisterData.self)
        try validations.add(\.name, .ascii)
        try validations.add(\.username, .alphanumeric && .count(3...))
        try validations.add(\.password, .count(8...))
        validations.add("password match") { model in
            guard model.password == model.confirmPassword else {
                throw BasicValidationError("passwords don't match")
            }
        }
        return validations
    }
}

