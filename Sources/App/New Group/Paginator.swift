import Vapor

struct Paginator {
    
    enum PaginatorType {
        case index
        case search(searchTerm: String)
        case tag(tagName: String)
        case user(username: String)
    }
    
    private let _currentPage: Int
    private let _type: PaginatorType
    private let _articlesPerPage = 3
    
    var currentPage: Int {
        return _currentPage
    }
    
    var articlesPerPage: Int {
        return _articlesPerPage
    }
    
    // The first article is number 0
    // The first page is number 1
    // I ask one more article than the needed articlesPerPage, to know if there is at least another article after
    //  to put in an future next page
    // I remove the last article when I pass the articles to the context of the leaf page
    var rangePlusOne: Range<Int> {
        let startArticle = (_currentPage - 1) * _articlesPerPage
        let endArticle = startArticle + _articlesPerPage
        return startArticle..<(endArticle + 1)
    }
    
    var newerPagePath: String? {
        
        switch _currentPage {
        case _ where  _currentPage <= 1: return nil
        case 2:
            switch _type {
            case .index: return "/"
            case .search(let searchTerm): return "/?search=\(searchTerm)"
            case .tag(let tagName): return "/tag/\(tagName)/"
            case .user(let username): return "/user/\(username)/"
        }
        default:
            switch _type {
            case .index: return "/page/\(_currentPage - 1)"
            case .search(let searchTerm): return "/page/\(_currentPage - 1)/?search=\(searchTerm)"
            case .tag(let tagName): return "/tag/\(tagName)/page/\(_currentPage - 1)"
            case .user(let username): return "/user/\(username)/page/\(_currentPage - 1)"
            }
        }
    }
    
    var olderPagePath: String {
        switch _type {
        case .index: return "/page/\(_currentPage + 1)"
        case .tag(let tagName): return "/tag/\(tagName)/page/\(_currentPage + 1)"
        case .user(let username): return "/user/\(username)/page/\(_currentPage + 1)"
        case .search(let searchTerm): return "/page/\(_currentPage + 1)/?search=\(searchTerm)"
        }
    }
    
    var tabTitle: String {
        switch _type {
        case .index:
            if _currentPage < 2 {
                return "MyBlog"
            } else {
                return "MyBlog - Page \(_currentPage)"
            }
        case .tag(let tagName):
            if _currentPage < 2 {
                return "\(tagName) : MyBlog"
            } else {
                return "\(tagName) : MyBlog - Page \(_currentPage)"
            }
        case .user(let username):
            if _currentPage < 2 {
                return "MyBlog : \(username)"
            } else {
                return "MyBlog : \(username) - Page \(_currentPage)"
            }
        case .search(let searchTerm):
            if _currentPage < 2 {
                return "\(searchTerm) : MyBlog"
            } else {
                return "\(searchTerm) : MyBlog - Page \(_currentPage)"
            }
        }
    }
    
    var pageTitle: String {
        switch _type {
        case .index:
            if _currentPage < 2 {
                return "Last articles on MyBlog"
            } else {
                return "Last articles on MyBlog - Page \(_currentPage)"
            }
        case .tag(let tagName):
            if _currentPage < 2 {
                return "Tag Archives : \(tagName)"
            } else {
                return "Tag Archives : \(tagName) - Page \(_currentPage)"
            }
        case .user(let username):
            if _currentPage < 2 {
                return "Last articles de \(username)"
            } else {
                return "Last articles de \(username) - Page \(_currentPage)"
            }
        case .search(let searchTerm):
            if _currentPage < 2 {
                return "Search Results for \(searchTerm)"
            } else {
                return "Search Results for \(searchTerm)- Page \(_currentPage)"
            }
        }
    }
        
    init(WithPageNumber pageNumber: Int, forType type: PaginatorType) {
        self._currentPage = pageNumber
        self._type = type
    }
    
}

