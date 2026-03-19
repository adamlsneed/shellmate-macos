import Testing; import Foundation; @testable import Shellmate
@Suite("ValidationService") struct ValidationServiceTests {
    @Test("checkConfig") func cc() { #expect(ValidationService().checkConfig().id=="config") }
    @Test("checkWorkspace") func cw() { #expect(ValidationService().checkWorkspace().id=="workspace") }
    @Test("checkWebSearch") func cs() { #expect(ValidationService().checkWebSearch().id=="webSearch") }
    @Test("ValidationCheck") func vc() { #expect(ValidationCheck(id:"t",name:"T",passed:true,detail:"OK").passed) }
}
