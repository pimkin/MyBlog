import Vapor

struct AdminPaginator {
    
    enum PaginatorType {
        case articles(searchTerm: String?)
        case tags(searchTerm: String?)
        case users(searchTerm: String?)
    }
    
    private let _currentPage: Int
    private let _type: PaginatorType
    private let _articlesPerPage = 8
    
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
            case .articles(let searchTerm):
                if let searchTerm = searchTerm {
                    return "/admin/articles?search=\(searchTerm)"
                } else {
                    return "/admin/articles"
                }
            case .tags(let searchTerm):
                if let searchTerm = searchTerm {
                    return "/admin/tags?search=\(searchTerm)"
                } else {
                    return "/admin/tags"
                }
            case .users(let searchTerm):
                if let searchTerm = searchTerm {
                    return "/admin/users?search=\(searchTerm)"
                } else {
                    return "/admin/users"
                }
            }
        default:
            switch _type {
            case .articles(let searchTerm):
                if let searchTerm = searchTerm {
                    return "/admin/articles/page/\(_currentPage - 1)/?search=\(searchTerm)"
                } else {
                    return "/admin/articles/page/\(_currentPage - 1)"
                }
            case .tags(let searchTerm):
                if let searchTerm = searchTerm {
                    return "/admin/tags/page/\(_currentPage - 1)/?search=\(searchTerm)"
                } else {
                    return "/admin/tags/page/\(_currentPage - 1)"
                }
            case .users(let searchTerm):
                if let searchTerm = searchTerm {
                    return "/admin/users/page/\(_currentPage - 1)/?search=\(searchTerm)"
                } else {
                    return "/admin/users/page/\(_currentPage - 1)"
                }
            }
        }
    }
    
    var olderPagePath: String {
        switch _type {
        case .articles(let searchTerm):
            if let searchTerm = searchTerm {
                return "/admin/articles/page/\(_currentPage + 1)/?search=\(searchTerm)"
            } else {
                return "/admin/articles/page/\(_currentPage + 1)"
            }
        case .tags(let searchTerm):
            if let searchTerm = searchTerm {
                return "/admin/tags/page/\(_currentPage + 1)/?search=\(searchTerm)"
            } else {
                return "/admin/tags/page/\(_currentPage + 1)"
            }
        case .users(let searchTerm):
            if let searchTerm = searchTerm {
                return "/admin/users/page/\(_currentPage + 1)/?search=\(searchTerm)"
            } else {
                return "/admin/users/page/\(_currentPage + 1)"
            }
            
        }
    }
    
    var tabTitle: String {
        switch _type {
        case .articles(let searchTerm):
            if _currentPage < 2 {
                return "MyBlog>Admin \(searchTerm ?? "") Articles"
            } else {
                return "MyBlog>Admin \(searchTerm ?? "") Articles - Page \(_currentPage)"
            }
        case .tags(let searchTerm):
            if _currentPage < 2 {
                return "MyBlog>Admin \(searchTerm ?? "") Tags"
            } else {
                return "MyBlog>Admin \(searchTerm ?? "") Tags - Page \(_currentPage)"
            }
        case .users(let searchTerm):
            if _currentPage < 2 {
                return "MyBlog>Admin \(searchTerm ?? "") Users"
            } else {
                return "MyBlog>Admin \(searchTerm ?? "")) Users - Page \(_currentPage)"
            }
        }
    }
    
    var pageTitle: String {
        switch _type {
        case .articles(let searchTerm):
            if _currentPage < 2 {
                return "\(searchTerm ?? "") Articles list"
            } else {
                return "\(searchTerm ?? "") Articles list - Page \(_currentPage)"
            }
        case .tags(let searchTerm):
            if _currentPage < 2 {
                return "\(searchTerm ?? "") Tags list"
            } else {
                return "\(searchTerm ?? "") Tag list - Page \(_currentPage)"
            }
        case .users(let searchTerm):
            if _currentPage < 2 {
                return "\(searchTerm ?? "") Users list"
            } else {
                return "\(searchTerm ?? "") Users list - Page \(_currentPage)"
            }
        }
    }
    
    init(WithPageNumber pageNumber: Int, forType type: PaginatorType) {
        self._currentPage = pageNumber
        self._type = type
    }
    
}


