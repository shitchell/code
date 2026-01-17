create or replace PACKAGE BODY LIB_APP AS
PROCEDURE TRACE
  (
   i_trace_proc     IN LIB_TRACE.TRACE_PROC%TYPE
  ,i_trace_user     IN LIB_TRACE.TRACE_USER%TYPE
  ,i_trace_level    IN LIB_TRACE.TRACE_LEVEL%TYPE
  ,i_trace_text     IN LIB_TRACE.TRACE_TEXT%TYPE
  ) IS
  pragma autonomous_transaction;

  CURSOR start_trace (cp_trace_user LIB_TRACE.TRACE_USER%TYPE) IS
      SELECT COUNT(*)
        FROM AS1.lib_trace_on
       WHERE traceon_username = cp_trace_user
         AND traceon_enabled = 'Y';

  v_traceon INTEGER :=0;
  BEGIN

      OPEN start_trace (cp_trace_user => i_trace_user);
      FETCH start_trace INTO v_traceon;
      CLOSE start_trace;

      IF v_traceon > 0 THEN
          INSERT INTO as1.lib_trace
            (
              trace_trans_id
              ,trace_proc
              ,trace_user
              ,trace_level
              ,trace_text
              ,trace_date
            )
          VALUES
          (
              trace_trans_seq.NEXTVAL
              ,i_trace_proc
              ,i_trace_user
              ,i_trace_level
              ,i_trace_text
              ,SYSDATE
              );
          commit;
      END IF;
  END TRACE;

END;
