import Testing; import Foundation; @testable import Shellmate
@Suite("JSONValue") struct JSONValueTests {
    @Test("string") func s() throws { let v=JSONValue.string("hi"); #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(v))==v) }
    @Test("int") func i() throws { let v=JSONValue.int(42); #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(v))==v) }
    @Test("double") func d() throws { let v=JSONValue.double(3.14); #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(v))==v) }
    @Test("bool") func b() throws { for b in [true,false] { #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(JSONValue.bool(b)))==JSONValue.bool(b)) } }
    @Test("null") func n() throws { #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(JSONValue.null))==JSONValue.null) }
    @Test("array") func a() throws { let v=JSONValue.array([.string("a"),.int(1)]); #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(v))==v) }
    @Test("object") func o() throws { let v=JSONValue.object(["k":.string("v")]); #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(v))==v) }
    @Test("nested") func ne() throws { let v=TestFixtures.complexJSONValue; #expect(try JSONDecoder().decode(JSONValue.self,from:JSONEncoder().encode(v))==v) }
    @Test("stringValue") func sv() { #expect(JSONValue.string("x").stringValue=="x"); #expect(JSONValue.int(1).stringValue==nil) }
    @Test("intValue") func iv() { #expect(JSONValue.int(7).intValue==7); #expect(JSONValue.string("7").intValue==nil) }
    @Test("anyValue") func av() { #expect(JSONValue.string("x").anyValue as? String=="x"); #expect(JSONValue.null.anyValue is NSNull) }
    @Test("inequality") func ineq() { #expect(JSONValue.string("1") != JSONValue.int(1)) }
}
