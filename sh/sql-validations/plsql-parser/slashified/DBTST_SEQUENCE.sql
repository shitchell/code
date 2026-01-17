--------------------------------------------------------
-- Sequence container for DBTST
--------------------------------------------------------

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

DECLARE
    v_max NUMBER;
BEGIN
    SELECT (NVL (MAX (DBTST_ID), 0) + 1) INTO v_max FROM DBTST;
    EXECUTE IMMEDIATE 'CREATE SEQUENCE  DBTST_ID_SEQ  MINVALUE 1 MAXVALUE 999999999999 INCREMENT BY 1 START WITH '||v_max||' CACHE 20 NOORDER NOCYCLE NOKEEP NOSCALE GLOBAL';
END;
/
