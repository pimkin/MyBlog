import Vapor
import Authentication
import FluentSQL

struct WebsiteAdminController: RouteCollection {
    
    let imageFolder = "ProfilePictures/"
    
    func boot(router: Router) throws {
        
        // the 'blog.com/admin/' route must have an authentified user, and the client
        //  is redirected to '/login' if no user is authentified
        let authSessRoutes = router.grouped(User.authSessionsMiddleware())
        let protectedRoutes = authSessRoutes.grouped(RedirectMiddleware(A: User.self, path: "/login"))
        let adminRoutes = protectedRoutes.grouped("admin")
        
        
        // The main page of the admin section -> blog.com/admin/
        adminRoutes.get("/", use: indexHandler)
        
        
        // MARK: - Routes for articles
        
        // where articles routes handler are defined
        let routeAdminArticles = RouteAdminArticles()
        
        // route for blog.com/admin/articles and blog.com/admin/articles/page/pageNumber
        adminRoutes.get("articles", use: routeAdminArticles.allArticlesHandler)
        adminRoutes.get("articles", "page", Int.parameter, use: routeAdminArticles.allArticlesPageHandler)
        // route for blog.com/admin/articles/create
        adminRoutes.get("articles", "create", use: routeAdminArticles.createArticleHandler)
        adminRoutes.post(AdminArticleData.self, at:"articles", "create", use: routeAdminArticles.createArticlePostHandler)
        // route for blog.com/admin/articles/articleID/edit
        adminRoutes.get("articles", Article.parameter, "edit", use: routeAdminArticles.editArticleHandler)
        adminRoutes.post(AdminArticleData.self, at:"articles", Article.parameter, "edit", use: routeAdminArticles.editArticlePostHandler)
        // route for blog.com/admin/articleID/delete
        adminRoutes.post("articles", Article.parameter, "delete", use: routeAdminArticles.deleteArticlePostHandler)
        
        
        // MARK: - Routes for Txt articles file (download and creation)
        
        // route for blog.com/admin/articles/createFromTxt
        adminRoutes.post(AdminTextArticleData.self, at:"articles", "createFromTxt", use: routeAdminArticles.createArticlesFromTxtHandler)
        // route for blog.com/admin/articles/download and blog.com/admin/articles/articleID/download
        adminRoutes.get("articles", "download", use: routeAdminArticles.downloadAllArticlesHandler)
        adminRoutes.get("articles", Article.parameter, "download", use: routeAdminArticles.downloadArticleHandler)
        
        
        // MARK: - Routes for tags
        
        // where tags routes handler are defined
        let routeAdminTags = RouteAdminTags()
        
        // Route for blog.com/admin/tags/ and blog.com/admin/tags/page/pageNumber
        adminRoutes.get("tags", use: routeAdminTags.allTagsHandler)
        adminRoutes.get("tags", "page", Int.parameter, use: routeAdminTags.allTagsPageHandler)
        // Route for blog.com/admin/tags/create/
        adminRoutes.get("tags", "create", use: routeAdminTags.createTagHandler)
        adminRoutes.post(AdminTagData.self, at:"tags", "create", use: routeAdminTags.createTagPostHandler)
        // Route for blog.com/admin/tags/tagID/edit/
        adminRoutes.get("tags", Tag.parameter, "edit", use: routeAdminTags.editTagHandler)
        adminRoutes.post(AdminTagData.self, at:"tags", Tag.parameter, "edit", use: routeAdminTags.editTagPostHandler)
        // Route for blog.com/admin/tags/tagID/delete/
        adminRoutes.post("tags", Tag.parameter, "delete", use: routeAdminTags.deleteTagPostHandler)
        
        // MARK: - Route for txt tags file
        
        // Route for blog.com/admin/tags/download
        adminRoutes.get("tags", "download", use: routeAdminTags.downloadTagsHandler)
        // Route for blog.com/admin/tags/tagID/download
        adminRoutes.get("tags", Tag.parameter, "download", use: routeAdminTags.downloadTagHandler)
        // Route for blog.com/tags/createFromTxt
        adminRoutes.post(AdminTagsTxtData.self, at:"tags", "createFromTxt", use: routeAdminTags.createTagsFromTxtPostHandler)
        
        
        
        // MARK: - Routes for users
        
        // where users routes handler are defined
        let routeAdminUsers = RouteAdminUsers()
        
        // Route for blog.com/admin/users/ and blog.com/admin/users/page/pageNumber
        adminRoutes.get("users", use: routeAdminUsers.allUsersHandler)
        adminRoutes.get("users", "page", Int.parameter, use: routeAdminUsers.allUsersPageHandler)
        // Route for blog.com/admin/users/userID/edit
        adminRoutes.get("users", User.parameter, "edit", use: routeAdminUsers.editUserHandler)
        adminRoutes.post(AdminUserData.self, at:"users", User.parameter, "edit", use: routeAdminUsers.editUserPostHandler)
        // Route for blog.com/admin/users/userID/delete
        adminRoutes.post("users", User.parameter, "delete", use: routeAdminUsers.deleteUserPostHandler)
        // Route for blog.com/admin/users/register
        adminRoutes.get("users", "register", use: routeAdminUsers.registerHandler)
        adminRoutes.post(AdminRegisterData.self, at:"users", "register", use: routeAdminUsers.registerPostHandler)
        
        // profilePictures routes
        //        adminRoutes.get("users", User.parameter, "profilePicture", use: getUsersProfilePictureHandler)
        //        adminRoutes.get("users", User.parameter, "addProfilePicture", use: addProfilePictureHandler)
        //        adminRoutes.post("users", User.parameter, "addProfilePicture", use: addProfilePicturePostHandler)
        
        // MARK: - Other routes
        
        adminRoutes.get("parameters", use: getParametersHandler)
        adminRoutes.post(AdminParametersData.self, at:"parameters", use: parametersPostHandler)
        
        // images routes
        //adminRoutes.get("Images", String.parameter, use: getImageHandler)
        adminRoutes.post(ImageUploadData.self, at:"Images", use: uploadImagePostHandler)
        
        
    }
    
    // Mark: - Index Route
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        let context = AdminIndexContext(tabTitle: "MyBlog>Admin",
                                        pageTitle: "Section Administration")
        return try req.view().render("admin/index", context)
    }

    
    func uploadImagePostHandler(_ req: Request, data: ImageUploadData) throws -> ImageLocation {
        
        let fileData = data.image.data
        let user = try req.requireAuthenticated(User.self)
        
        let filename = try "\(user.requireID())-\(UUID().uuidString).png"
        let workPath = DirectoryConfig.detect().workDir
        let imagePath = "Images/" + filename
        let path = workPath + imagePath
        
        FileManager().createFile(atPath: path,
                                 contents: fileData,
                                 attributes: nil)
        
        return ImageLocation(location: "/" + imagePath)
    }
    
    // MARK: - Parameters routes
    
    func getParametersHandler(_ req: Request) throws -> Future<View> {
        
        let parametersManager = BlogParametersManager.shared
        
        let context = AdminParametersContext(tabTitle: "MyBlog>Admin Parameters",
                                             pageTitle: "MyBlog parameters",
                                             blogName: parametersManager.blogName,
                                             articlesPerPage: parametersManager.articlesPerName)
        return try req.view().render("admin/parameters", context)
    }
    
    func parametersPostHandler(_ req: Request, data: AdminParametersData) throws -> Future<Response> {
        return Future.done(on: req).transform(to: req.redirect(to: "/admin/"))
    }
    
    
}

// MARK: - Struct Index

struct AdminIndexContext: Encodable {
    let tabTitle: String
    let pageTitle: String
}

// MARK: - Other

struct ImageUploadData: Content {
    var image: File
}

struct ImageLocation: Content {
    let location: String
}

// struct Parameters

struct AdminParametersContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let blogName: String
    let articlesPerPage: Int
}

struct AdminParametersData: Content {
    let name: String
    let articlesPerPage: Int
}
