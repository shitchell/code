--------------------------------------------------------
-- Function test for DBTST table
--------------------------------------------------------
-- This function is used to test the DBTST table (below) by returning a count of the number of records in the table
-- CREATE TABLE "DBTST"
--    (    "DBTST_ID" NUMBER,
--         "DBTST_NAME" VARCHAR2(100 BYTE),
--         "DBTST_DESC" VARCHAR2(100 BYTE),
--         "DBTST_DATE" DATE,
--         "DBTST_STATUS" VARCHAR2(1 BYTE),
--         "DBTST_MESSAGE" VARCHAR2(4000 BYTE),
--         "DBTST_CLOB" CLOB,
--         "CHANGE_USER" VARCHAR2(100 BYTE),
--         "CHANGE_DATE" DATE
--    );

CREATE OR REPLACE FUNCTION DBTEST_FUNCTION
RETURN NUMBER
AS
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM DBTST;
    RETURN v_count;
END DBTEST_FUNCTION;
/
