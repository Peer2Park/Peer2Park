//
//  AppConfig.swift
//  Peer2Park
//
//  Created by Trent S on 10/6/25.
//

import Foundation

enum AppEnvironment: String {
    case dev = "dev"
    case beta = "beta"
    case prod = "prod"
}

struct AppConfig {
    static var apiBaseURL: URL {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: urlString)
        else {
            fatalError("API_BASE_URL missing or invalid in Info.plist")
        }
        return url
    }

    static var environment: AppEnvironment {
        #if DEBUG
        return .dev
        #elseif BETA
        return .beta
        #else
        return .prod
        #endif
    }
}
