import Vapor

final class TagTextinator {
    
    static let separator = "----tag----"
    static let identifiers = ["--description--", "--name--"]
    
    
    func textFrom(tag: Tag) -> String {
        
        var text = "----tag----\r\n"
        text = text + "--name--\r\n" + "\(tag.name)\r\n"
        text = text + "--description--\r\n" + "\(tag.description)\r\n"
        
        return text
    }
    
    func textFileFrom(futureTag: Future<Tag>, on req: Request) throws -> Future<Response> {

        return futureTag.map(to: Response.self) { tag in
 
            let text = self.textFrom(tag: tag)
            let filename = "\(tag.name).txt"
            let data = text.convertToData()
            let response = req.response(data, as: .plainText)
            response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"\(filename)\"")
            return response
        }
    }
    
    func textFileFromAllTags(on req: Request) throws -> Future<Response> {
        
        return Tag.query(on: req).all().map(to: Response.self) { tags in
            var resultText = ""
            for tag in tags {
                let text = self.textFrom(tag: tag)
                resultText = resultText + text
            }
            
            let data = resultText.convertToData()
            let response = req.response(data, as: .plainText)
            response.http.headers.add(name: .contentDisposition, value: "attachment; filename=\"tags.txt\"")
            return response
        }
        
    }
    
    func tagFromText(text: String, on req: Request) throws -> Future<Tag> {
        
        var textTag = text
        
        let identifiers = ["--description--", "--name--"]
        var tagDictionary: [String: String] = [String: String]()
        for identifier in identifiers {
            let components = textTag.components(separatedBy: identifier)
            if let restOfComponents = components.first,
                let component = components.last {
                textTag = restOfComponents
                tagDictionary[identifier] = component
            }
        }
        
        guard let title = tagDictionary["--name--"],
            let description = tagDictionary["--description--"] else {
                throw Abort(.internalServerError)
        }
        
        return Tag(name: title, description: description).save(on: req)
    }
    
    func tagsFromFile(file: File, on req: Request) throws -> Future<[Tag]> {
        
        let txtData = file.data
        guard var tagsTxt = String(data: txtData, encoding: .utf8) else {
            throw Abort(HTTPResponseStatus.internalServerError)
        }
        
        tagsTxt = tagsTxt.replacingOccurrences(of: "\r", with: "")
        tagsTxt = tagsTxt.replacingOccurrences(of: "\n", with: "")
        
        // Split txt file with separator between articles
        let separator = "----tag----"
        var textTags = tagsTxt.components(separatedBy: separator)
        textTags = textTags.filter { textTag -> Bool in
            return textTag != ""
        }
        
        
        var tagsFuture = [Future<Tag>]()
        for textTag in textTags {
            
            let futureTag = try tagFromText(text: textTag, on: req)
            tagsFuture.append(futureTag)
        }
        
        return tagsFuture.flatten(on: req)
    }
    

}
