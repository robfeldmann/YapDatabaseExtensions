//
//  ValueWithObjectMetadataTests.swift
//  YapDatabaseExtensions
//
//  Created by Daniel Thorpe on 09/10/2015.
//  Copyright © 2015 Daniel Thorpe. All rights reserved.
//

import Foundation
import XCTest
@testable import YapDatabaseExtensions

class ValueWithObjectMetadataTests: XCTestCase {

    typealias TypeUnderTest = Inventory
    typealias MetadataTypeUnderTest = NSNumber

    var item: TypeUnderTest!
    var metadata: MetadataTypeUnderTest!
    var index: YapDB.Index!
    var key: String!

    var items: [TypeUnderTest]!
    var metadatas: [MetadataTypeUnderTest?]!
    var indexes: [YapDB.Index]!
    var keys: [String]!

    var database: TestableDatabase!
    var connection: TestableConnection!
    var writeTransaction: TestableWriteTransaction!
    var readTransaction: TestableReadTransaction!

    var reader: Read<TypeUnderTest, TestableDatabase>!

    var dispatchQueue: dispatch_queue_t!
    var operationQueue: NSOperationQueue!

    override func setUp() {
        super.setUp()
        createPersistables()
        index = item.index
        key = item.key

        indexes = items.map { $0.index }
        keys = items.map { $0.key }

        database = TestableDatabase()
        connection = TestableConnection()
        writeTransaction = TestableWriteTransaction()
        readTransaction = TestableReadTransaction()

        connection.readTransaction = readTransaction
        connection.writeTransaction = writeTransaction
        database.connection = connection

        dispatchQueue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)
        operationQueue = NSOperationQueue()
    }

    override func tearDown() {
        item = nil
        metadata = nil
        index = nil
        key = nil
        items = nil
        metadatas = nil
        indexes = nil
        keys = nil

        database = nil
        connection = nil
        writeTransaction = nil
        readTransaction = nil
        dispatchQueue = nil
        operationQueue = nil
        super.tearDown()
    }

    func createPersistables() {
        let products = [
            Product(
                identifier: "vodka-123",
                name: "Belvidere",
                barcode: .UPCA(1, 2, 3, 4)
            ),
            Product(
                identifier: "gin-123",
                name: "Boxer Gin",
                barcode: .UPCA(5, 10, 15, 20)
                ),
            Product(
                identifier: "rum-123",
                name: "Mount Gay Rum",
                barcode: .UPCA(12, 24, 39, 48)
                ),
            Product(
                identifier: "gin-234",
                name: "Monkey 47",
                barcode: .UPCA(31, 62, 93, 124)
                )
            ]

        metadatas = [
            NSNumber(integer: 12),
            NSNumber(integer: 13),
            NSNumber(integer: 14),
            NSNumber(integer: 15)
        ]
        items = products.map { TypeUnderTest(product: $0) }
        item = items[0]
        metadata = metadatas[0]
    }

    func configureForReadingSingle() {
        readTransaction.object = item.encoded
        readTransaction.metadata = metadata
    }

    func configureForReadingMultiple() {
        readTransaction.objects = items.encoded
        readTransaction.metadatas = metadatas.map { $0 }
        readTransaction.keys = keys
    }

    func checkTransactionDidWriteItem(result: (TypeUnderTest, MetadataTypeUnderTest?)) {
        XCTAssertEqual(result.0.identifier, item.identifier)
        XCTAssertFalse(writeTransaction.didWriteAtIndexes.isEmpty)
        XCTAssertEqual(writeTransaction.didWriteAtIndexes[0].0, index)
        XCTAssertEqual(TypeUnderTest.decode(writeTransaction.didWriteAtIndexes[0].1)!, item)
        XCTAssertEqual(writeTransaction.didWriteAtIndexes[0].2 as? NSNumber, metadata)
    }

    func checkTransactionDidWriteItems(result: [(TypeUnderTest, MetadataTypeUnderTest?)]) {
        XCTAssertFalse(writeTransaction.didWriteAtIndexes.isEmpty)
        XCTAssertEqual(writeTransaction.didWriteAtIndexes.map { $0.0.key }.sort(), indexes.map { $0.key }.sort())
        XCTAssertEqual(writeTransaction.didWriteAtIndexes.map { $0.2 }.count, items.count)
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(Set(result.map({$0.0})), Set(items))
    }

    func checkTransactionDidReadItem(result: (TypeUnderTest, MetadataTypeUnderTest?)?) -> Bool {
        XCTAssertEqual(readTransaction.didReadAtIndex, index)
        guard let result = result else {
            return false
        }
        XCTAssertEqual(readTransaction.didReadMetadataAtIndex, index)
        XCTAssertEqual(result.0.identifier, item.identifier)
        XCTAssertEqual(result.1, metadata)
        return true
    }

    func checkTransactionDidReadItems(result: [(TypeUnderTest, MetadataTypeUnderTest?)]) -> Bool {
        if result.isEmpty {
            return false
        }
        XCTAssertEqual(Set(readTransaction.didReadAtIndexes), Set(indexes))
        XCTAssertEqual(result.count, items.count)
        return true
    }

    func checkTransactionDidReadMetadataItem(result: MetadataTypeUnderTest?) -> Bool {
        XCTAssertNil(readTransaction.didReadAtIndex)
        guard let result = result else {
            return false
        }
        XCTAssertEqual(readTransaction.didReadMetadataAtIndex, index)
        XCTAssertEqual(result, metadata)
        return true
    }

    func checkTransactionDidReadMetadataItems(result: [MetadataTypeUnderTest]) -> Bool {
        XCTAssertTrue(readTransaction.didReadAtIndexes.isEmpty)
        if result.isEmpty {
            return false
        }
        XCTAssertEqual(Set(readTransaction.didReadMetadataAtIndexes), Set(indexes))
        XCTAssertEqual(result.count, items.count)
        return true
    }

    func checkTransactionDidRemoveItem() {
        XCTAssertEqual(writeTransaction.didRemoveAtIndexes.count, 1)
        XCTAssertEqual(writeTransaction.didRemoveAtIndexes.first!, index)
    }

    func checkTransactionDidRemoveItems() {
        XCTAssertEqual(writeTransaction.didRemoveAtIndexes, indexes)
    }
}


// MARK: - Tests

class Base_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__metadata_is_not_nil() {
        XCTAssertNotNil(metadata)
    }
}

class Functional_Read_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    // Functional API - ReadTransactionType - Reading

    func test__transaction__read_at_index_with_data() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadItem(readTransaction.readWithMetadataAtIndex(index)))
    }

    func test__transaction__read_at_index_without_data() {
        XCTAssertFalse(checkTransactionDidReadItem(readTransaction.readWithMetadataAtIndex(index)))
    }

    func test__transaction__read_at_indexes_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(readTransaction.readWithMetadataAtIndexes(indexes)))
    }

    func test__transaction__read_at_indexes_with_data_2() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(readTransaction.readWithMetadataAtIndexes(Set(indexes))))
    }

    func test__transaction__read_at_indexes_without_data() {
        XCTAssertFalse(checkTransactionDidReadItems(readTransaction.readWithMetadataAtIndexes(indexes)))
    }

    func test__transaction__read_by_key_with_data() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadItem(readTransaction.readWithMetadataByKey(key)))
    }

    func test__transaction__read_by_key_without_data() {
        XCTAssertFalse(checkTransactionDidReadItem(readTransaction.readWithMetadataByKey(key)))
    }

    func test__transaction__read_by_keys_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(readTransaction.readWithMetadataByKeys(keys)))
    }

    func test__transaction__read_by_keys_with_data_2() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(readTransaction.readWithMetadataByKeys(Set(keys))))
    }

    func test__transaction__read_by_keys_without_data() {
        XCTAssertFalse(checkTransactionDidReadItems(readTransaction.readWithMetadataByKeys(keys)))
    }

    func test__transaction__read_all_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(readTransaction.readWithMetadataAll()))
    }

    // Functional API - ConnectionType - Reading

    func test__connection__read_at_index_with_data() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadItem(connection.readWithMetadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_at_index_without_data() {
        XCTAssertFalse(checkTransactionDidReadItem(connection.readWithMetadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_at_indexes_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.readWithMetadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_at_indexes_with_data_2() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.readWithMetadataAtIndexes(Set(indexes))))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_at_indexes_without_data() {
        XCTAssertFalse(checkTransactionDidReadItems(connection.readWithMetadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_by_key_with_data() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadItem(connection.readWithMetadataByKey(key)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_by_key_without_data() {
        XCTAssertFalse(checkTransactionDidReadItem(connection.readWithMetadataByKey(key)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_by_keys_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.readWithMetadataByKeys(keys)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_by_keys_with_data_2() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.readWithMetadataByKeys(Set(keys))))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_by_keys_without_data() {
        XCTAssertFalse(checkTransactionDidReadItems(connection.readWithMetadataByKeys(keys)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_all_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.readWithMetadataAll()))
        XCTAssertTrue(connection.didRead)
    }
}

class Functional_Read_Metadata_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__transaction__read_metadata_at_index() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadMetadataItem(readTransaction.readMetadataAtIndex(index)))
    }

    func test__transaction__read_metadata_at_index_no_data() {
        XCTAssertFalse(checkTransactionDidReadMetadataItem(readTransaction.readMetadataAtIndex(index)))
    }

    func test__transaction__read_metadata_at_indexes() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadMetadataItems(readTransaction.readMetadataAtIndexes(indexes)))
    }

    func test__transaction__read_metadata_at_indexes_no_data() {
        XCTAssertFalse(checkTransactionDidReadMetadataItems(readTransaction.readMetadataAtIndexes(indexes)))
    }

    func test__connection__read_metadata_at_index() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadMetadataItem(connection.readMetadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_metadata_at_index_no_data() {
        XCTAssertFalse(checkTransactionDidReadMetadataItem(connection.readMetadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_metadata_at_indexes() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadMetadataItems(connection.readMetadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }

    func test__connection__read_metadata_at_indexes_no_data() {
        XCTAssertFalse(checkTransactionDidReadMetadataItems(connection.readMetadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }
}

class Functional_Write_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__transaction__write_item() {
        checkTransactionDidWriteItem(writeTransaction.writeWithMetadata((item, metadata)))
    }

    func test__transaction__write_items() {
        checkTransactionDidWriteItems(writeTransaction.writeWithMetadata(zipToWrite(items, metadatas)))
    }

    // MARK: - Functional API - Connection - Writing

    func test__connection__write_item() {
        checkTransactionDidWriteItem(connection.writeWithMetadata((item, metadata)))
        XCTAssertTrue(connection.didWrite)
    }

    func test__connection__write_items() {
        checkTransactionDidWriteItems(connection.writeWithMetadata(zipToWrite(items, metadatas)))
        XCTAssertTrue(connection.didWrite)
    }

    func test__connection__async_write_item() {
        var result: (TypeUnderTest, MetadataTypeUnderTest?)!
        let expectation = expectationWithDescription("Test: \(#function)")
        connection.asyncWriteWithMetadata((item, metadata)) { tmp in
            result = tmp
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidWriteItem(result)
        XCTAssertTrue(connection.didAsyncWrite)
    }

    func test__connection__async_write_items() {
        var result: [(TypeUnderTest, MetadataTypeUnderTest?)] = []
        let expectation = expectationWithDescription("Test: \(#function)")
        connection.asyncWriteWithMetadata(zipToWrite(items, metadatas)) { received in
            result = received
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidWriteItems(result)
        XCTAssertTrue(connection.didAsyncWrite)
    }
}

class Functional_Remove_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__transaction_remove_item() {
        configureForReadingSingle()
        writeTransaction.remove(item)
        checkTransactionDidRemoveItem()
    }

    func test__transaction_remove_items() {
        configureForReadingMultiple()
        writeTransaction.remove(items)
        checkTransactionDidRemoveItems()
    }

    func test__connection_remove_item() {
        configureForReadingSingle()
        connection.remove(item)
        checkTransactionDidRemoveItem()
        XCTAssertTrue(connection.didWrite)
    }

    func test__connection_remove_items() {
        configureForReadingMultiple()
        connection.remove(items)
        checkTransactionDidRemoveItems()
        XCTAssertTrue(connection.didWrite)
    }

    func test__connection_async_remove_item() {
        let expectation = expectationWithDescription("Test: \(#function)")
        configureForReadingSingle()
        connection.asyncRemove(item) {
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidRemoveItem()
        XCTAssertTrue(connection.didAsyncWrite)
    }

    func test__connection_async_remove_items() {
        let expectation = expectationWithDescription("Test: \(#function)")
        configureForReadingMultiple()
        connection.asyncRemove(items) {
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidRemoveItems()
        XCTAssertTrue(connection.didAsyncWrite)
    }
}

class Curried_Read_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    // MARK: - Persistable Curried API - Reading

    func test__curried__read_at_index_with_data() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadItem(connection.read(TypeUnderTest.readWithMetadataAtIndex(index))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_at_index_with_no_data() {
        XCTAssertFalse(checkTransactionDidReadItem(connection.read(TypeUnderTest.readWithMetadataAtIndex(index))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_at_indexes_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.read(TypeUnderTest.readWithMetadataAtIndexes(indexes))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_at_indexes_with_no_data() {
        XCTAssertFalse(checkTransactionDidReadItems(connection.read(TypeUnderTest.readWithMetadataAtIndexes(indexes))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_by_key_with_data() {
        configureForReadingSingle()
        XCTAssertTrue(checkTransactionDidReadItem(connection.read(TypeUnderTest.readWithMetadataByKey(key))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_by_key_with_no_data() {
        XCTAssertFalse(checkTransactionDidReadItem(connection.read(TypeUnderTest.readWithMetadataByKey(key))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_by_keys_with_data() {
        configureForReadingMultiple()
        XCTAssertTrue(checkTransactionDidReadItems(connection.read(TypeUnderTest.readWithMetadataByKeys(keys))))
        XCTAssertTrue(connection.didRead)
    }

    func test__curried__read_by_keys_with_no_data() {
        XCTAssertFalse(checkTransactionDidReadItems(connection.read(TypeUnderTest.readWithMetadataByKeys(keys))))
        XCTAssertTrue(connection.didRead)
    }
}

class Curried_Write_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__curried__write() {
        checkTransactionDidWriteItem(connection.write(item.writeWithMetadata(metadata)))
        XCTAssertTrue(connection.didWrite)
    }
}

class Persistable_Read_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    // Reading - Internal

    func test__reader__in_transaction_at_index() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItem(reader.withMetadataInTransaction(readTransaction, atIndex: index)))
    }

    func test__reader__in_transaction_at_index_2() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        let atIndex: YapDB.Index -> (TypeUnderTest, MetadataTypeUnderTest?)? = reader.withMetadataInTransactionAtIndex(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItem(atIndex(index)))
    }

    func test__reader__at_index_in_transaction() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        let inTransaction: TestableReadTransaction -> (TypeUnderTest, MetadataTypeUnderTest?)? = reader.withMetadataAtIndexInTransaction(index)
        XCTAssertTrue(checkTransactionDidReadItem(inTransaction(readTransaction)))
    }

    func test__reader__at_indexes_in_transaction_with_items() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataAtIndexesInTransaction(indexes)(readTransaction)))
    }

    func test__reader__at_indexes_in_transaction_with_no_items() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataAtIndexesInTransaction(indexes)(readTransaction)))
    }

    func test__reader__in_transaction_by_key() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItem(reader.withMetadataInTransaction(readTransaction, byKey: key)))
    }

    func test__reader__in_transaction_by_key_2() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        let byKey: String -> (TypeUnderTest, MetadataTypeUnderTest?)? = reader.withMetadataInTransactionByKey(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItem(byKey(key)))
    }

    func test__reader__by_key_in_transaction() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        let inTransaction: TestableReadTransaction -> (TypeUnderTest, MetadataTypeUnderTest?)? = reader.withMetadataByKeyInTransaction(key)
        XCTAssertTrue(checkTransactionDidReadItem(inTransaction(readTransaction)))
    }

    func test__reader__by_keys_in_transaction_with_items() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataByKeysInTransaction(keys)(readTransaction)))
    }

    func test__reader__by_keys_in_transaction_with_items_with_keys() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataByKeysInTransaction()(readTransaction)))
    }

    func test__reader__by_keys_in_transaction_with_no_items() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataByKeysInTransaction(keys)(readTransaction)))
    }

    // Reading - With Transaction

    func test__reader_with_transaction__at_index_with_item() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItem(reader.withMetadataInTransaction(readTransaction, atIndex: index)))
    }

    func test__reader_with_transaction__at_index_with_no_item() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItem(reader.withMetadataAtIndex(index)))
    }

    func test__reader_with_transaction__at_indexes_with_items() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataAtIndexes(indexes)))
    }

    func test__reader_with_transaction__at_indexes_with_no_items() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataAtIndexes(indexes)))
    }

    func test__reader_with_transaction__by_key_with_item() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItem(reader.withMetadataInTransaction(readTransaction, atIndex: index)))
    }

    func test__reader_with_transaction__by_key_with_no_item() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItem(reader.withMetadataByKey(key)))
    }

    func test__reader_with_transaction__by_keys_with_items() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataByKeys(keys)))
    }

    func test__reader_with_transaction__by_keys_with_no_items() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataByKeys(keys)))
    }

    func test__reader_with_transaction__all_with_items() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataAll()))
        XCTAssertEqual(readTransaction.didKeysInCollection, TypeUnderTest.collection)
    }

    func test__reader_with_transaction__all_with_no_items() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataAll()))
        XCTAssertEqual(readTransaction.didKeysInCollection, TypeUnderTest.collection)
    }

    func test__reader_with_transaction__filter() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        let (items, missing): ([(TypeUnderTest, MetadataTypeUnderTest?)], [String]) = reader.withMetadataFilterExisting(keys)
        XCTAssertEqual(readTransaction.didReadAtIndexes.first!, indexes.first!)
        XCTAssertEqual(items.map { $0.0.identifier }, items.prefixUpTo(1).map { $0.0.identifier })
        XCTAssertEqual(missing, Array(keys.suffixFrom(1)))
    }

    // Reading - With Connection

    func test__reader_with_connection__at_index_with_item() {
        configureForReadingSingle()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadItem(reader.withMetadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__at_index_with_no_item() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadItem(reader.withMetadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__at_indexes_with_items() {
        configureForReadingMultiple()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__at_indexes_with_no_items() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__by_key_with_item() {
        configureForReadingSingle()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadItem(reader.withMetadataByKey(key)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__by_key_with_no_item() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadItem(reader.withMetadataByKey(key)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__by_keys_with_items() {
        configureForReadingMultiple()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataByKeys(keys)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__by_keys_with_no_items() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataByKeys(keys)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__all_with_items() {
        configureForReadingMultiple()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadItems(reader.withMetadataAll()))
        XCTAssertTrue(connection.didRead)
        XCTAssertEqual(readTransaction.didKeysInCollection, TypeUnderTest.collection)
    }

    func test__reader_with_connection__all_with_no_items() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadItems(reader.withMetadataAll()))
        XCTAssertTrue(connection.didRead)
        XCTAssertEqual(readTransaction.didKeysInCollection, TypeUnderTest.collection)
    }

    func test__reader_with_connection__filter() {
        configureForReadingSingle()
        reader = Read(connection)
        let (items, missing) = reader.filterExisting(keys)
        XCTAssertTrue(connection.didRead)
        XCTAssertEqual(readTransaction.didReadAtIndexes.first!, indexes.first!)
        XCTAssertEqual(items.map { $0.identifier }, items.prefixUpTo(1).map { $0.identifier })
        XCTAssertEqual(missing, Array(keys.suffixFrom(1)))
    }

}

class Persistable_Read_Metadata_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__reader_with_transaction__read_metadata_at_index() {
        configureForReadingSingle()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadMetadataItem(reader.metadataAtIndex(index)))
    }

    func test__reader_with_transaction__read_metadata_at_index_no_data() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadMetadataItem(reader.metadataAtIndex(index)))
    }

    func test__reader_with_transaction__read_metadata_at_indexes() {
        configureForReadingMultiple()
        reader = Read(readTransaction)
        XCTAssertTrue(checkTransactionDidReadMetadataItems(reader.metadataAtIndexes(indexes)))
    }

    func test__reader_with_transaction__read_metadata_at_indexes_no_data() {
        reader = Read(readTransaction)
        XCTAssertFalse(checkTransactionDidReadMetadataItems(reader.metadataAtIndexes(indexes)))
    }

    func test__reader_with_connection__read_metadata_at_index() {
        configureForReadingSingle()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadMetadataItem(reader.metadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__read_metadata_at_index_no_data() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadMetadataItem(reader.metadataAtIndex(index)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__read_metadata_at_indexes() {
        configureForReadingMultiple()
        reader = Read(connection)
        XCTAssertTrue(checkTransactionDidReadMetadataItems(reader.metadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)
    }

    func test__reader_with_connection__read_metadata_at_indexes_no_data() {
        reader = Read(connection)
        XCTAssertFalse(checkTransactionDidReadMetadataItems(reader.metadataAtIndexes(indexes)))
        XCTAssertTrue(connection.didRead)        
    }
}

class Persistable_Write_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__item_persistable__write_using_transaction() {
        checkTransactionDidWriteItem(item.writeWithMetadata(writeTransaction, metadata: metadata))
    }

    func test__item_persistable__write_using_connection() {
        checkTransactionDidWriteItem(item.writeWithMetadata(connection, metadata: metadata))
        XCTAssertTrue(connection.didWrite)
    }

    func test__item_persistable__write_async_using_connection() {
        let expectation = expectationWithDescription("Test: \(#function)")
        var result: (TypeUnderTest, MetadataTypeUnderTest?)! = nil

        item.asyncWriteWithMetadata(connection, metadata: metadata) { tmp in
            result = tmp
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidWriteItem(result)
        XCTAssertTrue(connection.didAsyncWrite)
    }

    func test__item_persistable__write_using_opertion() {
        let expectation = expectationWithDescription("Test: \(#function)")

        let operation = item.writeWithMetadataOperation(connection, metadata: metadata)
        operation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperation(operation)
        waitForExpectationsWithTimeout(3.0, handler: nil)
        XCTAssertFalse(writeTransaction.didWriteAtIndexes.isEmpty)
        XCTAssertEqual(writeTransaction.didWriteAtIndexes[0].0, index)
        XCTAssertEqual(TypeUnderTest.decode(writeTransaction.didWriteAtIndexes[0].1)!, item)
        XCTAssertEqual(writeTransaction.didWriteAtIndexes[0].2 as? NSNumber, metadata)
        XCTAssertTrue(connection.didWrite)
    }

    func test__items_persistable__write_using_transaction() {
        checkTransactionDidWriteItems(items.writeWithMetadata(writeTransaction, metadata: metadatas))
    }

    func test__items_persistable__write_using_connection() {
        checkTransactionDidWriteItems(items.writeWithMetadata(connection, metadata: metadatas))
        XCTAssertTrue(connection.didWrite)
    }

    func test__items_persistable__write_async_using_connection() {
        let expectation = expectationWithDescription("Test: \(#function)")
        var result: [(TypeUnderTest, MetadataTypeUnderTest?)] = []
        
        items.asyncWriteWithMetadata(connection, metadata: metadatas) { tmp in
            result = tmp
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidWriteItems(result)
        XCTAssertTrue(connection.didAsyncWrite)
    }

    func test__items_persistable__write_using_opertion() {
        let expectation = expectationWithDescription("Test: \(#function)")

        let operation = items.writeWithMetadataOperation(connection, metadata: metadatas)
        operation.completionBlock = {
            expectation.fulfill()
        }

        operationQueue.addOperation(operation)
        waitForExpectationsWithTimeout(3.0, handler: nil)
        XCTAssertFalse(writeTransaction.didWriteAtIndexes.isEmpty)
        XCTAssertEqual(writeTransaction.didWriteAtIndexes.map { $0.0.key }.sort(), indexes.map { $0.key }.sort())
        XCTAssertEqual(writeTransaction.didWriteAtIndexes.map { $0.2 }.count, items.count)
        XCTAssertTrue(connection.didWrite)
    }    
}

class Persistable_Remove_ValueWithObjectMetadataTests: ValueWithObjectMetadataTests {

    func test__transaction__remove_item() {
        configureForReadingSingle()
        item.remove(writeTransaction)
        checkTransactionDidRemoveItem()
    }

    func test__connection_remove_item() {
        configureForReadingSingle()
        item.remove(connection)
        checkTransactionDidRemoveItem()
        XCTAssertTrue(connection.didWrite)
    }

    func test__connection_async_remove_item() {
        let expectation = expectationWithDescription("Test: \(#function)")
        configureForReadingSingle()
        item.asyncRemove(connection) {
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidRemoveItem()
        XCTAssertTrue(connection.didAsyncWrite)
    }

    func test__connection_operation_remove_item() {
        let expectation = expectationWithDescription("Test: \(#function)")
        configureForReadingSingle()
        let operation = item.removeOperation(connection)
        operation.completionBlock = {
            expectation.fulfill()
        }
        operationQueue.addOperation(operation)
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidRemoveItem()
        XCTAssertTrue(connection.didWrite)
    }

    func test__transaction__remove_items() {
        configureForReadingMultiple()
        items.remove(writeTransaction)
        checkTransactionDidRemoveItems()
    }


    func test__connection_remove_items() {
        configureForReadingMultiple()
        items.remove(connection)
        checkTransactionDidRemoveItems()
        XCTAssertTrue(connection.didWrite)
    }

    func test__connection_async_remove_items() {
        let expectation = expectationWithDescription("Test: \(#function)")
        configureForReadingMultiple()
        items.asyncRemove(connection) {
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidRemoveItems()
        XCTAssertTrue(connection.didAsyncWrite)
    }

    func test__connection_operation_remove_items() {
        let expectation = expectationWithDescription("Test: \(#function)")
        configureForReadingMultiple()
        let operation = items.removeOperation(connection)
        operation.completionBlock = {
            expectation.fulfill()
        }
        operationQueue.addOperation(operation)
        waitForExpectationsWithTimeout(3.0, handler: nil)
        checkTransactionDidRemoveItems()
        XCTAssertTrue(connection.didWrite)
    }
}
