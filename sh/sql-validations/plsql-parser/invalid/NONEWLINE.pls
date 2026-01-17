create or replace
FUNCTION DBTEST_FUNCTION_NOSLASH
RETURN NUMBER
AS
    v_count NUMBER:=8; /* more comments */
BEGIN    RETURN v_count;    END DBTEST_FUNCTION_NOSLASH; -- yet another comment

-- idk just a comment

/*
  and another comment
*/

/* and yet more comments */
