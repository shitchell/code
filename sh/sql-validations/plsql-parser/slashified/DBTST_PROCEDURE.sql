--------------------------------------------------------
-- Procedure test for DBTST table
--------------------------------------------------------
-- This procedure is used to test the DBTST table, it will insert a record into the table
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

CREATE OR REPLACE PROCEDURE DBTEST_PROCEDURE
AS
BEGIN
   INSERT INTO DBTST (DBTST_ID, DBTST_NAME, DBTST_DESC, DBTST_DATE, DBTST_STATUS, DBTST_MESSAGE, DBTST_CLOB, CHANGE_USER, CHANGE_DATE)
   VALUES (DBTST_ID_SEQ.NEXTVAL, 'DBTST_NAME_1', 'DBTST_DESC_1', TO_DATE('2017-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'A', 'DBTST_MESSAGE_1', 'DBTST_CLOB_1', 'DBTST_USER_1', TO_DATE('2017-01-01 00:00:00', 'YYYY-MM-DD HH24:MI:SS'));
END DBTEST_PROCEDURE;
/
