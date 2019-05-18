import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    let websiteController = WebsiteController()
    try router.register(collection: websiteController)
    
    let websiteAdminController = WebsiteAdminController()
    try router.register(collection: websiteAdminController)
    
}
