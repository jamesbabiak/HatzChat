import Foundation

// MARK: - Hatz Apps (App Builder)

struct HatzAppListResponse: Decodable {
    let data: [HatzApp]
}

struct HatzApp: Identifiable, Decodable, Hashable {
    let id: String

    let name: String
    let description: String?
    let default_model: String?
    let files: [HatzAppFile]
    let constants: [HatzAppConstant]?
    let user_inputs: [HatzAppUserInput]
    let prompt_sections: [HatzPromptSection]

    enum CodingKeys: String, CodingKey {
        case id
        case app_id
        case uuid
        case name
        case description
        case default_model
        case files
        case constants
        case user_inputs
        case prompt_sections
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // /app/list has been observed to return one of these keys depending on backend version.
        if let v = try c.decodeIfPresent(String.self, forKey: .id) {
            self.id = v
        } else if let v = try c.decodeIfPresent(String.self, forKey: .app_id) {
            self.id = v
        } else if let v = try c.decodeIfPresent(String.self, forKey: .uuid) {
            self.id = v
        } else {
            // Keep UI stable even if backend response is missing an id.
            self.id = "missing-id-\(UUID().uuidString)"
        }

        self.name = try c.decode(String.self, forKey: .name)
        self.description = try c.decodeIfPresent(String.self, forKey: .description)
        self.default_model = try c.decodeIfPresent(String.self, forKey: .default_model)

        self.files = try c.decodeIfPresent([HatzAppFile].self, forKey: .files) ?? []
        self.constants = try c.decodeIfPresent([HatzAppConstant].self, forKey: .constants)
        self.user_inputs = try c.decodeIfPresent([HatzAppUserInput].self, forKey: .user_inputs) ?? []
        self.prompt_sections = try c.decodeIfPresent([HatzPromptSection].self, forKey: .prompt_sections) ?? []
    }
}

struct HatzAppFile: Decodable, Hashable, Identifiable {
    var id: String { file_key }

    let size: Int
    let module: String
    let file_id: String?
    let type_id: String?
    let file_key: String
    let file_type: String
    let object_id: String
    let description: String
    let display_name: String
    let variable_name: String
    let variable_type: String
}

struct HatzAppConstant: Decodable, Hashable, Identifiable {
    var id: String { object_id }

    let object_id: String
    let variable_name: String
    let display_name: String
    let description: String?
    let variable_type: String
    let value: String
}

struct HatzAppUserInput: Decodable, Hashable, Identifiable {
    var id: String { object_id }

    let position: Int
    let required: Bool
    let object_id: String
    let description: String
    let display_name: String
    let variable_name: String
    let variable_type: String
}

struct HatzPromptSection: Decodable, Hashable, Identifiable {
    var id: String { "\(position)-\(body.hashValue)" }
    let body: String
    let position: Int
}

// MARK: - Query

struct HatzAppQueryRequest: Encodable {
    let inputs: [String: String]
    let model: String?
    let stream: Bool
    let file_uuids: [String]?

    init(inputs: [String: String], model: String?, stream: Bool = false, fileUUIDs: [String]? = nil) {
        self.inputs = inputs
        self.model = model
        self.stream = stream
        self.file_uuids = fileUUIDs
    }
}

struct HatzAppQueryResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
            let role: String
        }
        let message: Message
    }
    let choices: [Choice]
    let model: String?
}
