import Testing; import Foundation; @testable import Shellmate
@Suite("AgentSpec") struct AgentSpecTests {
    @Test("defaults") func d() { let s=AgentSpec(); #expect(s.id=="main"); #expect(s.name==""); #expect(s.macApps.isEmpty) }
    @Test("round-trip") func rt() throws { let s=TestFixtures.sampleAgentSpec(); let d=try JSONDecoder().decode(AgentSpec.self,from:JSONEncoder().encode(s)); #expect(d.name==s.name); #expect(d.macApps==s.macApps); #expect(d.never==s.never) }
    @Test("snake_case keys") func ck() throws { let j=try JSONSerialization.jsonObject(with:JSONEncoder().encode(TestFixtures.sampleAgentSpec())) as! [String:Any]; #expect(j["mac_apps"] != nil); #expect(j["macApps"]==nil) }
}
