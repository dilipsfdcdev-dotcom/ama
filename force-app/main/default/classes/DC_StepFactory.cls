public with sharing class DC_StepFactory {
    public static DC_IStep make(String name) {
        if (name == 'Account')    return new DC_AccountStep();
        if (name == 'Commission') return new DC_CommissionStep();
        return null;
    }
}
