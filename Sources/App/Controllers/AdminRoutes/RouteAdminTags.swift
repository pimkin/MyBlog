import Vapor
import FluentSQL

final class RouteAdminTags {
    
    
    // MARK:- Tag Routes
    
    // Route for blog.com/admin/tags/
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
    
    // Route for blog.com/admin/tags/page/pageNumber
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
    
    
    // GET Route for blog.com/admin/tags/create/
    func createTagHandler(_ req: Request) throws -> Future<View> {
        let context = AdminTagContext(tabTitle: "MyBlog>Admin : Create a New Tag",
                                      pageTitle: "Créer un nouveau Tag",
                                      tag: nil,
                                      isEditing: false)
        
        return try req.view().render("admin/tag", context)
    }
    
    // POST Route for blog.com/admin/tags/create/
    func createTagPostHandler(_ req:Request, data: AdminTagData) throws -> Future<Response> {
        return Tag(name: data.name, description: data.description).save(on: req).transform(to: req.redirect(to: "/admin/tags"))
    }
    
    // GET Route for blog.com/admin/tags/tagID/edit/
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
    
    // POST Route for blog.com/admin/tags/tagID/edit/
    func editTagPostHandler(_ req: Request, data: AdminTagData) throws -> Future<Response> {
        let futureTag = try req.parameters.next(Tag.self)
        
        return futureTag.flatMap(to: Response.self) { tag in
            
            tag.name = data.name
            tag.description = data.description
            
            return tag.update(on: req).transform(to: req.redirect(to: "/admin/tags"))
        }
    }
    
    // POST Route for blog.com/admin/tags/tagID/delete/
    func deleteTagPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameters.next(Tag.self).flatMap(to: Response.self) { tag in
            return tag.delete(on: req).transform(to: req.redirect(to: "/admin/tags"))
        }
    }
    
}

// MARK: - Struct Tags

// for GET blog.com/admin/tags/
struct AdminTagsContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let tags: [Tag]
    let olderPagePath: String?
    let newerPagePath: String?
}

// for GET blog.com/admin/tags/tagID/edit
struct AdminTagContext: Encodable {
    let tabTitle: String
    let pageTitle: String
    let tag: Tag?
    var isEditing: Bool
}

// for POST blog.com/admin/tags/tagID/edit
struct AdminTagData: Content {
    let name: String
    let description: String
}
