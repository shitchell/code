--------------------------------------------------------
--  DDL for Index DBTST2 Table
--------------------------------------------------------

-- DROP the DBTST2 table if it exists
DROP TABLE DBTST2 CASCADE CONSTRAINTS PURGE;

CREATE TABLE "DBTST2"
   (    "DBTST2_ID" NUMBER,
        "DBTST2_NAME" VARCHAR2(100 BYTE),
        "DBTST2_DESC" VARCHAR2(100 BYTE),
        "DBTST2_DATE" DATE,
        "DBTST2_STATUS" VARCHAR2(1 BYTE),
        "DBTST2_MESSAGE" VARCHAR2(4000 BYTE),
        "DBTST2_CLOB" CLOB,
        "CHANGE_USER" VARCHAR2(100 BYTE),
        "CHANGE_DATE" DATE
   );

--------------------------------------------------------
--  DDL for Index DBTST2_PK
--------------------------------------------------------

CREATE UNIQUE INDEX "DBTST2_PK" ON "DBTST2" ("DBTST2_ID");

--------------------------------------------------------
--  DDL for Sequence DBTST2_ID
--------------------------------------------------------

CREATE SEQUENCE "DBTST2_ID_SEQ" MINVALUE 1 MAXVALUE 999999999999 INCREMENT BY 1 START WITH 1 CACHE 20 NOORDER NOCYCLE NOKEEP NOSCALE GLOBAL;
