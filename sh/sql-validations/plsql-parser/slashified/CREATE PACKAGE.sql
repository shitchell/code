--------------------------------------------------------
-- Package test for DBTST
--------------------------------------------------------

-- This package is used to test the DBTST table (below) by returning a count of the number of records in the table
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

CREATE OR REPLACE PACKAGE DBTEST_PACKAGE
AS
    FUNCTION DBTEST_FUNCTION
    RETURN NUMBER;
    PROCEDURE DBTEST_PROCEDURE;
END DBTEST_PACKAGE;
/
