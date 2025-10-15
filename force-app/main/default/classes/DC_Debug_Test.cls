@IsTest
private class DC_Debug_Test {
    
    @IsTest
    static void testEnableFlag() {
        System.assertEquals(false, DC_Debug.ENABLE);
        
        DC_Debug.ENABLE = true;
        System.assertEquals(true, DC_Debug.ENABLE);
        
        DC_Debug.ENABLE = false;
        System.assertEquals(false, DC_Debug.ENABLE);
    }
    
    @IsTest
    static void testMaxRowsFlag() {
        System.assertEquals(0, DC_Debug.MAX_ROWS);
        
        DC_Debug.MAX_ROWS = 10;
        System.assertEquals(10, DC_Debug.MAX_ROWS);
        
        DC_Debug.MAX_ROWS = 100;
        System.assertEquals(100, DC_Debug.MAX_ROWS);
        
        DC_Debug.MAX_ROWS = 0;
        System.assertEquals(0, DC_Debug.MAX_ROWS);
    }
    
    @IsTest
    static void testDebugMode() {
        DC_Debug.ENABLE = true;
        DC_Debug.MAX_ROWS = 50;
        
        System.assertEquals(true, DC_Debug.ENABLE);
        System.assertEquals(50, DC_Debug.MAX_ROWS);
    }
    
    @IsTest
    static void testProductionMode() {
        DC_Debug.ENABLE = false;
        DC_Debug.MAX_ROWS = 0;
        
        System.assertEquals(false, DC_Debug.ENABLE);
        System.assertEquals(0, DC_Debug.MAX_ROWS);
    }
}