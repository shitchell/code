create or replace procedure OHD_GET_PROJECT_ACCOUNTING
(
  I_PASSPORT            IN TIDPPOPT.PASSPORT%TYPE
 ,I_PROJECT_NBR_NEW     IN TIDACDST.PROJECT_NBR%TYPE
 ,I_PROJECT_NBR_OLD     IN TIDACDST.PROJECT_NBR%TYPE
 ,I_A_XREF_CODE         IN TIDACDST.A_XREF_CODE%TYPE
 ,I_FORCE_PROJECT       IN BOOLEAN DEFAULT FALSE
 ,I_COST_CENTER_CUR     IN TIDACDST.COST_CENTER_CHARGE%TYPE DEFAULT NULL
 ,I_ACCOUNT_NBR_CUR     IN TIDACDST.ACCOUNT_NBR%TYPE DEFAULT NULL
 ,O_COST_CENTER         OUT TIDACDST.COST_CENTER_CHARGE%TYPE
 ,O_ACTIVITY_ID         OUT TIDACDST.ACTIVITY_ID%TYPE
 ,O_ACCOUNT_NBR         OUT TIDACDST.ACCOUNT_NBR%TYPE
 ,O_USER_DEF            OUT TIDACDST.USER_DEF%TYPE
)
AS
/**************************************************************************
 Author     : VIC BERG
 Date       : 01/04/2023

 Revision History
 Date            User        Description
 01/04/2023      VBERG       Initial Version
***************************************************************************/
V_COUNT                 INTEGER;
V_ACCOUNT_NBR_NEW       TIDACDST.ACCOUNT_NBR%TYPE;
V_COST_CENTER_NEW       TIDACDST.COST_CENTER_CHARGE%TYPE;
V_ACTIVITY_ID_NEW       TIDACDST.ACTIVITY_ID%TYPE DEFAULT ' ';
V_COST_CENTER_CUR       TIDACDST.COST_CENTER_CHARGE%TYPE DEFAULT ' ';
V_ACTIVITY_ID_CUR       TIDACDST.ACTIVITY_ID%TYPE DEFAULT ' ';
V_USER_DEF_CUR          TIDACDST.USER_DEF%TYPE DEFAULT ' ';
V_ACCOUNT_NBR_CUR       TIDACDST.ACCOUNT_NBR%TYPE DEFAULT ' ';
V_ACCOUNT_NBR_OLD       TIDACDST.ACCOUNT_NBR%TYPE DEFAULT ' ';
V_COST_CENTER_OLD       TIDACDST.COST_CENTER_CHARGE%TYPE DEFAULT ' ';
V_DEPARTMENT            TIDPPOPT.DEPARTMENT%TYPE;

BEGIN
/**************************************************************************
 Project Accounting
 1) This is only called when project is added or changed
 2) Check prior accounting.
 3) If prior accounting had a project, pull project cost center/account nbr
 4) If prior accounting did not have a project, pull cost center/account nbr
 5) If cost center or account nbr does not match, keep them.
 6) Otherwise apply project cost center, account nbr and activity id, if one
    exists
 7) If not forcing project accounting, keep the user def if one exists
 8) Force project is set when we want to completely replace accounting
***************************************************************************/
    LIB_APP.TRACE('GET PROJECT ACCOUNTING', 'OPG', 1,'PLANNER: ' || I_PASSPORT);

    IF I_A_XREF_CODE > ' ' AND I_COST_CENTER_CUR IS NULL AND I_ACCOUNT_NBR_CUR IS NULL THEN
        SELECT COUNT(*)
          INTO V_COUNT
          FROM TIDACDST
         WHERE A_XREF_CODE = I_A_XREF_CODE;

        IF V_COUNT > 0 THEN
            SELECT COST_CENTER_CHARGE
                  ,ACTIVITY_ID
                  ,ACCOUNT_NBR
                  ,USER_DEF
              INTO V_COST_CENTER_CUR
                  ,V_ACTIVITY_ID_CUR
                  ,V_ACCOUNT_NBR_CUR
                  ,V_USER_DEF_CUR
              FROM TIDACDST A
             WHERE A_XREF_CODE = I_A_XREF_CODE
               AND GEN_ARG IN
                   (SELECT MIN(GEN_ARG)
                      FROM TIDACDST B
                     WHERE B.A_XREF_CODE = A.A_XREF_CODE);
        END IF;
    END IF;

    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'CUR COST CENTER: ' || V_COST_CENTER_CUR);
    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'CUR ACCOUNT NBR: ' || V_ACCOUNT_NBR_CUR);
    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'CUR USER DEF: ' || V_USER_DEF_CUR);

    -- Get Account Nbr/Cost Center/Activity Id for new project.  Activity Id is always applied
    IF I_PROJECT_NBR_NEW > ' ' THEN
        SELECT PROJECT_TYPE,
               COST_CENTER,
               PROJ_CATEGORY_CD
          INTO V_ACCOUNT_NBR_NEW,
               V_COST_CENTER_NEW,
               V_ACTIVITY_ID_NEW
          FROM TIDPJMST
         WHERE PROJECT_NBR = I_PROJECT_NBR_NEW;
    END IF;

    -- If changing projects, get the original project Account Nbr/Cost Center
    IF I_PROJECT_NBR_OLD > ' ' THEN
        SELECT PROJECT_TYPE,
               COST_CENTER
          INTO V_ACCOUNT_NBR_OLD,
               V_COST_CENTER_OLD
          FROM TIDPJMST
         WHERE PROJECT_NBR = I_PROJECT_NBR_OLD;
    END IF;
--    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'OLD COST CENTER: ' || V_COST_CENTER_OLD);
--    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'OLD ACCOUNT NBR: ' || V_ACCOUNT_NBR_OLD);

    IF I_COST_CENTER_CUR IS NOT NULL THEN
        V_COST_CENTER_CUR := I_COST_CENTER_CUR;
    END IF;
    IF I_ACCOUNT_NBR_CUR IS NOT NULL THEN
        V_ACCOUNT_NBR_CUR := I_ACCOUNT_NBR_CUR;
    END IF;

/**************************************************************************
 Apply Cost Center
 1) If changing a project, check if original project cost center changed by user.
 2) Keep if changed, use new project cost center if not
 3) If new project, check if default cost center changed by user.
 4) Keep if changed, use new project cost center if not
***************************************************************************/
    IF I_PROJECT_NBR_OLD > ' ' AND V_COST_CENTER_OLD > ' ' THEN
        IF V_COST_CENTER_CUR != V_COST_CENTER_OLD AND V_COST_CENTER_CUR > ' ' AND I_FORCE_PROJECT = FALSE THEN
            O_COST_CENTER := V_COST_CENTER_CUR;
        ELSE
            O_COST_CENTER := V_COST_CENTER_NEW;
        END IF;
    ELSE
        V_DEPARTMENT := OHD_GET_DEPARTMENT(I_PASSPORT);
        IF V_DEPARTMENT != V_COST_CENTER_CUR  AND V_COST_CENTER_CUR > ' ' AND I_FORCE_PROJECT = FALSE THEN
            O_COST_CENTER := V_COST_CENTER_CUR;
        ELSE
            O_COST_CENTER := V_COST_CENTER_NEW;
        END IF;
    END IF;

/**************************************************************************
 Apply Account Nbr
 1) If changing a project, check if original project account nbr changed by user.
 2) Keep if changed, use new project account nbr if not
 3) If new project, check if original default account nbr changed by user.
 4) Keep if changed, use new project account nbr if not
***************************************************************************/
    IF I_PROJECT_NBR_OLD > ' ' AND V_ACCOUNT_NBR_OLD > ' ' AND I_FORCE_PROJECT = FALSE THEN
        IF V_ACCOUNT_NBR_CUR != V_ACCOUNT_NBR_OLD AND I_FORCE_PROJECT = FALSE THEN
            O_ACCOUNT_NBR := V_ACCOUNT_NBR_CUR;
        ELSE
            O_ACCOUNT_NBR := V_ACCOUNT_NBR_NEW;
        END IF;
    ELSE
        IF V_ACCOUNT_NBR_CUR != '62000   ' AND V_ACCOUNT_NBR_CUR > ' '  AND I_FORCE_PROJECT = FALSE  THEN
            O_ACCOUNT_NBR := V_ACCOUNT_NBR_CUR;
        ELSE
            O_ACCOUNT_NBR := V_ACCOUNT_NBR_NEW;
        END IF;
    END IF;

/**************************************************************************
 Apply Activity Id
 1) Use project activity id if exists
 2) Use existing activity id if exists
 3) Set to spaces otherwise
***************************************************************************/
    IF V_ACTIVITY_ID_NEW > ' ' THEN
        O_ACTIVITY_ID := V_ACTIVITY_ID_NEW;
    ELSIF V_ACTIVITY_ID_CUR > ' ' AND I_FORCE_PROJECT = FALSE THEN
        O_ACTIVITY_ID := V_ACTIVITY_ID_CUR;
    ELSE
        O_ACTIVITY_ID := ' ';
    END IF;

/**************************************************************************
 Apply User Def
 1) If new project accounting, always set user def to spaces
***************************************************************************/
--    IF V_COST_CENTER_CUR = O_COST_CENTER AND V_ACCOUNT_NBR_CUR = O_ACCOUNT_NBR AND I_FORCE_PROJECT = FALSE AND I_PROJECT_NBR_N = I_PROJECT_NBR_OLD THEN
--        IF V_USER_DEF_CUR > ' ' THEN
--            O_USER_DEF := V_USER_DEF_CUR;
--        ELSE
--            O_USER_DEF := ' ';
--        END IF;
--    ELSE
        O_USER_DEF := ' ';
--    END IF;

--    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'NEW COST CENTER: ' || O_COST_CENTER);
--    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'NEW ACTIVITY ID: ' || O_ACTIVITY_ID);
--    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'NEW ACCOUNT NBR: ' || O_ACCOUNT_NBR);
--    LIB_APP.TRACE('SET PROJECT ACCOUNTING', 'OPG', 1,'NEW USER DEF: ' || O_USER_DEF);
END;
/