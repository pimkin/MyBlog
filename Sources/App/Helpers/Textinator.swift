import Vapor

final class Textinator {
    
    static let separator = "----article----"
    //static let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--author", "--snippet--", "--slugURL--", "--title--"]
    static let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--snippet--", "--slugURL--", "--title--"]
    
    func textFrom(article: Article) -> String {
        
        var resultText = ""
        
        var text = "----article----"
        text = text + "--title--\r\n" + "\(article.title)\r\n"
        text = text + "--slugURL--\r\n" + "\(article.slugURL)\r\n"
        text = text + "--snippet--\r\n" + "\(article.snippet)\r\n"
        //text = text + "--author--\r\n" + "\(article.snippet)\r\n"
        text = text + "--created--\r\n" + "\(article.snippet)\r\n"
        text = text + "--edited--\r\n" + "\(article.snippet)\r\n"
        text = text + "--published--\r\n" + "\(article.snippet)\r\n"
        text = text + "--mainPicture--\r\n" + "\(article.snippet)\r\n"
        text = text + "--content--\r\n" + "\(article.content)"
        resultText = resultText + text
        
        return resultText
    }
    
    func textFileFrom(futureArticle: Future<Article>, on req: Request) throws -> Future<Response> {

        return futureArticle.map(to: Response.self) { article in
 
            let text = self.textFrom(article: article)
            let filename = "\(article.slugURL).txt"
            let data = text.convertToData()
            let response = req.response(data, as: .plainText)
            response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
            return response
        }
    }
    
    func textFileFromAllArticles(on req: Request) throws -> Future<Response> {
        
        return Article.query(on: req).all().map(to: Response.self) { articles in
            var resultText = ""
            for article in articles {
                let text = self.textFrom(article: article)
                resultText = resultText + text
            }
            
            let data = resultText.convertToData()
            let response = req.response(data, as: .plainText)
            response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"articles.txt\"")
            return response
        }
        
    }
    
    func articleFromText(text: String, on req: Request) throws -> Future<Article> {
        
        var textArticle = text
        
        let identifiers = ["--content--", "--mainPicture--", "--published--", "--edited--", "--created--", "--author", "--snippet--", "--slugURL--", "--title--"]
        var articleDictionary: [String: String] = [String: String]()
        for identifier in identifiers {
            let components = textArticle.components(separatedBy: identifier)
            if let restOfComponents = components.first,
                let component = components.last {
                textArticle = restOfComponents
                articleDictionary[identifier] = component
            }
        }
        
        guard let title = articleDictionary["--title--"],
            let slugURL = articleDictionary["--slugURL--"],
            let snippet = articleDictionary["--snippet--"],
            //let author = articleDictionary["--author--"],
            //let created = articleDictionary["--created--"],
            let mainPicture = articleDictionary["--mainPicture--"],
            let content = articleDictionary["--content--"] else {
                throw Abort(.internalServerError)
        }
        
        let published: Date? = nil
//        if let publishedDateString = articleDictionary["--published--"] {
//            published =
//        }
        let edited: Date? = nil
        let created = Date()
        
        let user = try req.requireAuthenticated(User.self)
        
        
        
        return Article(title: title,
                                       slugURL: slugURL,
                                       content: content,
                                       snippet: snippet,
                                       authorID: try user.requireID(),
                                       created: created,
                                       edited: edited,
                                       published: published,
                                       mainPicture: mainPicture).save(on: req)
    }
    
    func articlesFromFile(file: File, on req: Request) throws -> Future<[Article]> {
        
        let txtData = file.data
        guard var articlesTxt = String(data: txtData, encoding: .utf8) else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        
        articlesTxt = articlesTxt.replacingOccurrences(of: "\r", with: "")
        articlesTxt = articlesTxt.replacingOccurrences(of: "\n", with: "")
        
        // Split txt file with separator between articles
        let separator = "----article----"
        var textArticles = articlesTxt.components(separatedBy: separator)
        textArticles = textArticles.filter { textArticle -> Bool in
            return textArticle != ""
        }
        
        
        var articlesFuture = [Future<Article>]()
        for textArticle in textArticles {
            
            let futureArticle = try articleFromText(text: textArticle, on: req)
            articlesFuture.append(futureArticle)
        }
        
        return articlesFuture.flatten(on: req)
    }
    

}
