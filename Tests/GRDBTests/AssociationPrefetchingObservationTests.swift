import XCTest
import GRDB

private struct A: TableRecord { }
private struct B: TableRecord { }
private struct C: TableRecord { }
private struct D: TableRecord { }

class AssociationPrefetchingObservationTests: GRDBTestCase {
    private func assertRequestRegionEqual<T>(
        _ db: Database,
        _ request: QueryInterfaceRequest<T>,
        _ expectedDescriptions: String...,
        file: StaticString = #file, line: UInt = #line) throws
    {
        // Test DatabaseRegionConvertible
        let region1 = try request.databaseRegion(db)
        XCTAssertTrue(expectedDescriptions.contains(region1.description), description, file: file, line: line)
        
        // Test raw statement region, as support for Database.recordingSelection
        let region2 = try request
            .makePreparedRequest(db, forSingleResult: false)
            .statement
            .databaseRegion
        XCTAssertTrue(expectedDescriptions.contains(region2.description), description, file: file, line: line)
    }
    
    override func setup(_ dbWriter: DatabaseWriter) throws {
        try dbWriter.write { db in
            try db.create(table: "a") { t in
                t.autoIncrementedPrimaryKey("cola1")
                t.column("cola2", .text)
            }
            try db.create(table: "b") { t in
                t.autoIncrementedPrimaryKey("colb1")
                t.column("colb2", .integer).references("a")
                t.column("colb3", .text)
            }
            try db.create(table: "c") { t in
                t.autoIncrementedPrimaryKey("colc1")
                t.column("colc2", .integer).references("a")
            }
            try db.create(table: "d") { t in
                t.autoIncrementedPrimaryKey("cold1")
                t.column("cold2", .integer).references("c")
                t.column("cold3", .text)
            }
        }
    }
    
    func testIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(B.self))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),b(colb1,colb2,colb3)")
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") == 4)
                        .forKey("bs1"))
                    .including(all: A
                        .hasMany(B.self)
                        .filter(Column("colb1") != 4)
                        .forKey("bs2"))

                try assertRequestRegionEqual(db, request, "a(cola1,cola2),b(colb1,colb2,colb3)")
            }
            
            // Request with altered selection
            do {
                let request = A
                    .including(all: A
                        .hasMany(B.self)
                        .select(Column("colb1")))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),b(colb1,colb2)")
            }
        }
    }
    
    func testIncludingAllHasManyIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(all: C
                            .hasMany(D.self)))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .forKey("ds2"))
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .forKey("ds1"))
                        .including(all: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .forKey("ds2"))
                        .forKey("cs2"))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
        }
    }
    
    func testIncludingAllHasManyIncludingRequiredOrOptionalHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(C.self)
                        .including(required: C
                            .hasMany(D.self)))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") > 7)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .forKey("d2"))
                        .forKey("cs1"))
                    .including(all: A
                        .hasMany(C.self)
                        .filter(Column("colc1") < 9)
                        .including(optional: C
                            .hasMany(D.self)
                            .filter(Column("cold1") == 11)
                            .forKey("d1"))
                        .including(required: C
                            .hasMany(D.self)
                            .filter(Column("cold1") != 11)
                            .forKey("d2"))
                        .forKey("cs2"))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
        }
    }
    
    func testIncludingAllHasManyThroughHasManyUsingHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.read { db in
            // Plain request
            do {
                let request = A
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self), using: C.hasMany(D.self)))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
            
            // Request with filters
            do {
                let request = A
                    .filter(Column("cola1") != 3)
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).filter(Column("colc1") == 8).forKey("cs1"), using: C.hasMany(D.self))
                        .forKey("ds1"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).forKey("cs2"), using: C.hasMany(D.self))
                        .filter(Column("cold1") != 11)
                        .forKey("ds2"))
                    .including(all: A
                        .hasMany(D.self, through: A.hasMany(C.self).forKey("cs2"), using: C.hasMany(D.self))
                        .filter(Column("cold1") == 11)
                        .forKey("ds3"))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
        }
    }
    
    func testIncludingOptionalBelongsToIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .including(all: A
                            .hasMany(C.self))
                    )
                
                try assertRequestRegionEqual(
                    db, request,
                    "a(*),b(colb1,colb2,colb3),c(colc1,colc2)",
                    "a(cola1,cola2),b(colb1,colb2,colb3),c(colc1,colc2)")
            }
            
            // Request with filters
            do {
                let request = B
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a1")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .forKey("cs2"))
                        .forKey("a1"))
                    .including(optional: B
                        .belongsTo(A.self)
                        .filter(Column("cola2") == "a2")
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") == 9)
                            .forKey("cs1"))
                        .including(all: A
                            .hasMany(C.self)
                            .filter(Column("colc1") != 9)
                            .forKey("cs2"))
                        .forKey("a2"))
                
                try assertRequestRegionEqual(db, request, "a(cola1,cola2),b(colb1,colb2,colb3),c(colc1,colc2)")
            }
        }
    }
    
    func testJoiningOptionalHasOneThroughIncludingAllHasMany() throws {
        let dbQueue = try makeDatabaseQueue()
        try dbQueue.write { db in
            // Plain request
            do {
                let request = D
                    .joining(optional: D
                        .hasOne(A.self, through: D.belongsTo(C.self), using: C.belongsTo(A.self))
                        .including(all: A
                            .hasMany(B.self)
                            .orderByPrimaryKey()))
                    .orderByPrimaryKey()
                
                try assertRequestRegionEqual(
                    db, request,
                    "a(*),b(colb1,colb2,colb3),c(colc1,colc2),d(cold1,cold2,cold3)",
                    "a(cola1),b(colb1,colb2,colb3),c(colc1,colc2),d(cold1,cold2,cold3)")
            }
        }
    }
}
