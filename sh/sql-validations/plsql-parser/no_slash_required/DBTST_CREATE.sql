--------------------------------------------------------
--  DDL for Index DBTST Table
--------------------------------------------------------

-- DROP the DBTST table if it exists
DROP TABLE DBTST CASCADE CONSTRAINTS PURGE;

CREATE TABLE "DBTST"
   (    "DBTST_ID" NUMBER,
        "DBTST_NAME" VARCHAR2(100 BYTE),
        "DBTST_DESC" VARCHAR2(100 BYTE),
        "DBTST_DATE" DATE,
        "DBTST_STATUS" VARCHAR2(1 BYTE),
        "DBTST_MESSAGE" VARCHAR2(4000 BYTE),
        "DBTST_CLOB" CLOB,
        "CHANGE_USER" VARCHAR2(100 BYTE),
        "CHANGE_DATE" DATE
   );

--------------------------------------------------------
--  DDL for Index DBTST_PK
--------------------------------------------------------

CREATE UNIQUE INDEX "DBTST_PK" ON "DBTST" ("DBTST_ID");

--------------------------------------------------------
--  DDL for Sequence DBTST_ID
--------------------------------------------------------

CREATE SEQUENCE "DBTST_ID_SEQ" MINVALUE 1 MAXVALUE 999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER NOCYCLE NOKEEP NOSCALE GLOBAL;
