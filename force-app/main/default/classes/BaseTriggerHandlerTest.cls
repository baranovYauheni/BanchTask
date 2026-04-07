@IsTest
private class BaseTriggerHandlerTest {
    
    private class DummyHandler extends BaseTriggerHandler {
        public void invokeSuperMethods() {
            super.onBeforeInsert(new List<SObject>());
            super.onBeforeUpdate(new List<SObject>(), new Map<Id, SObject>());
            super.onAfterInsert(new List<SObject>());
            super.onAfterUpdate(new List<SObject>(), new Map<Id, SObject>());
        }
    }
    
    @IsTest
    static void testVirtualMethods() {
        DummyHandler handler = new DummyHandler();
        
        Test.startTest();
        handler.invokeSuperMethods();
        Test.stopTest();
        
        System.assert(true, 'Virtual methods executed successfully');
    }
}
