import Vapor
import FluentSQL
import Authentication

final class RouteAdminUsers {
    
    // MARK:- Users Routes
    
    
    // route for blog.com/admin/users
    //  -> list all the users on the blog
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
    
    // route for blog.com/admin/users/page/pageNumber
    //  -> list all the users on the blog (with pagination)
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
    
    // GET Route for blog.com/admin/users/userID/edit
    func editUserHandler(_ req: Request) throws -> Future<View> {
        let futureUser = try req.parameters.next(User.self)
        
        return futureUser.flatMap(to: View.self) { user in
            let context = AdminUserContext(title: "MyBlog>Admin",
                                           user: user.convertToPublic())
            return try req.view().render("admin/user", context)
        }
    }
    
    // POST Route for blog.com/admin/users/userID/edit
    func editUserPostHandler(_ req: Request, data: AdminUserData) throws -> Future<Response> {
        let futureProfile = try req.parameters.next(User.self)
        
        return futureProfile.flatMap(to: Response.self) { profile in
            profile.name = data.name
            profile.username = data.username
            
            return futureProfile.update(on: req).transform(to: req.redirect(to: "/admin/users"))
        }
    }
    
    // GET Route for blog.com/admin/users/userID/delete
    func deleteUserPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(User.self).flatMap(to: Response.self) { user in
            return user.delete(on: req).transform(to: req.redirect(to: "/admin/users"))
        }
    }
    
    // MARK: - Register User route
    
    // GET Route for blog.com/admin/users/register
    func registerHandler(_ req: Request) throws -> Future<View> {
        
        return Tag.query(on: req).all().flatMap(to: View.self) { tags in
            
            var context = AdminRegisterContext(tabTitle: "MyBlog - Register",
                                          pageTitle: "Register",
                                          tags: tags,
                                          message: nil)
            if let message = req.query[String.self, at: "message"] {
                context.message = message
            }
            
            return try req.view().render("admin/register", context)
        }
    }
    
    // POST Route for blog.com/admin/users/register
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
            
            // Create User Directory in Images to store user images
            
            do {
                let uuid = try user.requireID()
                let workPath = DirectoryConfig.detect().workDir
                let userImagePath = workPath + "Images/" + "\(uuid)"
                try FileManager().createDirectory(atPath: userImagePath,
                                                  withIntermediateDirectories: false,
                                                  attributes: nil)
            } catch {
                fatalError("Can't create user Image folder")
            }
            
            return req.redirect(to: "/admin/users")
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
