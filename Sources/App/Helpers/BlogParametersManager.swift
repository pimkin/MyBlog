import Vapor

class BlogParametersManager {
    
    private static var _blogParametersManager: BlogParametersManager? = nil
    
    public static var shared: BlogParametersManager {
        if _blogParametersManager == nil {
            _blogParametersManager = BlogParametersManager()
        }
        return _blogParametersManager!
    }
    
    private var _parameters: BlogParameters
    
    public var blogName: String {
        return _parameters.blogName
    }
    
    public var articlesPerName: Int {
        return _parameters.articlesPerPage
    }
    
    private init() {
        let workingDirectory = DirectoryConfig.detect()
        let configFileURL = URL(fileURLWithPath: workingDirectory.workDir).appendingPathComponent("parameters.json")
        do {
            let dataFile = try Data.init(contentsOf: configFileURL)
            let parameters = try JSONDecoder().decode(BlogParameters.self, from: dataFile)
            _parameters = parameters
        } catch let error {
            print("error in loading blog config file : \(error.localizedDescription)")
            fatalError("can't load blog config file")
        }
        
        print("hello")
        
        
    }
    
    
}

struct BlogParameters : Codable {
    let blogName: String
    let articlesPerPage: Int
}
