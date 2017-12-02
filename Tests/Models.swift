//
//  Models.swift
//  YapDBExtensionsMobile
//
//  Created by Daniel Thorpe on 15/04/2015.
//  Copyright (c) 2015 Daniel Thorpe. All rights reserved.
//

import Foundation
import YapDatabase
import YapDatabaseExtensions

public enum Barcode: Equatable {
    case upca(Int, Int, Int, Int)
    case qrCode(String)
}

extension Barcode: Codable {
    enum CodingError: Error {
        case decoding(String)
    }
    
    private enum CodingKeys: String, CodingKey {
        case upca
        case qrCode
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .upca(numberSystem, manufacturer, product, check):
            try container.encode([numberSystem, manufacturer, product, check], forKey: .upca)
            
        case let .qrCode(productCode):
            try container.encode(productCode, forKey: .qrCode)
            
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let codes = try? container.decode(Array<Int>.self, forKey: .upca), codes.count == 4 {
            self = .upca(codes[0], codes[1], codes[2], codes[3])
            return
        }
        if let code = try? container.decode(String.self, forKey: .qrCode) {
            self = .qrCode(code)
            return
        }
        throw CodingError.decoding("Decoding Error: \(dump(container))")
    }
}

public struct Product: Identifiable, Equatable, Codable {

    public struct Category: Identifiable, Codable {
        public let identifier: Int
        let name: String
    }

    public struct Metadata: Equatable, Codable {
        let categoryIdentifier: Int

        public init(categoryIdentifier: Int) {
            self.categoryIdentifier = categoryIdentifier
        }
    }

    public let identifier: Identifier
    internal let name: String
    internal let barcode: Barcode

    public init(identifier: Identifier, name: String, barcode: Barcode) {
        self.identifier = identifier
        self.name = name
        self.barcode = barcode
    }
}

public struct Inventory: Identifiable, Equatable, Codable {
    let product: Product

    public var identifier: Identifier {
        return product.identifier
    }
}

public class NamedEntity: NSObject, NSCoding {

    @objc public let identifier: Identifier
    public let name: String

    public init(id: String, name n: String) {
        identifier = id
        name = n
    }

    public required init?(coder aDecoder: NSCoder) {
        identifier = aDecoder.decodeObject(forKey: "identifier") as! Identifier
        name = aDecoder.decodeObject(forKey: "name") as! String
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(identifier, forKey: "identifier")
        aCoder.encode(name, forKey: "name")
    }
}

public class Person: NamedEntity { }

public class Employee: NamedEntity {
}

public class Manager: NamedEntity {
    public struct Metadata: Equatable, Codable {
        public let numberOfDirectReports: Int
    }
}

// MARK: - Equatable

public func == (a: Barcode, b: Barcode) -> Bool {
    switch (a, b) {
    case let (.upca(aNS, aM, aP, aC), .upca(bNS, bM, bP, bC)):
        return (aNS == bNS) && (aM == bM) && (aP == bP) && (aC == bC)
    case let (.qrCode(aCode), .qrCode(bCode)):
        return aCode == bCode
    default:
        return false
    }
}

public func == (a: Product, b: Product) -> Bool {
    return a.identifier == b.identifier
}

public func == (a: Product.Metadata, b: Product.Metadata) -> Bool {
    return a.categoryIdentifier == b.categoryIdentifier
}

public func == (a: Inventory, b: Inventory) -> Bool {
    return (a.product == b.product)
}

public func == (a: NamedEntity, b: NamedEntity) -> Bool {
    return (a.identifier == b.identifier) && (a.name == b.name)
}

public func == (a: Manager.Metadata, b: Manager.Metadata) -> Bool {
    return a.numberOfDirectReports == b.numberOfDirectReports
}

// MARK: - Hashable etc

extension Barcode: Hashable {
    public var hashValue: Int {
        return identifier
    }
}

extension Product: Hashable {
    public var hashValue: Int {
        return barcode.hashValue
    }
}

extension Inventory: Hashable {
    public var hashValue: Int {
        return product.hashValue
    }
}

extension Product.Metadata: Hashable {
    public var hashValue: Int {
        return categoryIdentifier.hashValue
    }
}

extension Manager.Metadata: Hashable {
    public var hashValue: Int {
        return numberOfDirectReports.hashValue
    }
}

extension NamedEntity {

    public override var description: String {
        return "id: \(identifier), name: \(name)"
    }
}

// MARK: - Persistable

extension Barcode: Persistable {

    public static var collection: String {
        return "Barcodes"
    }

    public var identifier: Int {
        switch self {
        case let .upca(numberSystem, manufacturer, product, check):
            return "\(numberSystem).\(manufacturer).\(product).\(check)".hashValue
        case let .qrCode(code):
            return code.hashValue
        }
    }
}

extension Product.Category: Persistable {

    public static var collection: String {
        return "Categories"
    }
}

extension Product: Persistable {

    public static var collection: String {
        return "Products"
    }
}

extension Inventory: Persistable {

    public static var collection: String {
        return "Inventory"
    }
}

extension Person: Persistable {

    public static var collection: String {
        return "People"
    }
}

extension Employee: Persistable {

    public static var collection: String {
        return "Employees"
    }
}

extension Manager: Persistable {

    public static var collection: String {
        return "Managers"
    }
}

// MARK: - Database Views

public func products() -> YapDB.Fetch {

    let grouping: YapDB.View.Grouping = .byMetadata({ (_, collection, key, metadata) -> String! in
        if collection == Product.collection,
           let metadata = metadata,
           let productMetadata = try? Product.Metadata(from: metadata) {
            return "category: \(productMetadata.categoryIdentifier)"
        }
        return nil
    })

    let sorting: YapDB.View.Sorting = .byObject({ (_, group, collection1, key1, object1, collection2, key2, object2) -> ComparisonResult in
        
        if let product1 = try? Product(from: object1),
           let product2 = try? Product(from: object2) {
            return product1.name.caseInsensitiveCompare(product2.name)
        }
        return .orderedSame
    })

    let view = YapDB.View(
        name: "Products grouped by category",
        grouping: grouping,
        sorting: sorting,
        collections: [Product.collection])

    return .view(view)
}




