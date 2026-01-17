#!/bin/bash
########################################################################################################
# SQL_checker.sh (initially syntax_parser.sh),                                                         #
# Laurence Ho consulting (c) Jul 2023, all rights reserved.                                            #
# Purpose:                                                                                             #
#  This script was created to report *basic* syntax errors in SQL scripts for both SQL & PL/SQL stmts  #
# Conditions and Standards:                                                                            #
#  SQL scripts should be written in a certain way, nothing special, but just in a way that most        #
#  people would, and it's according to most common and best practises. If the basics are not followed  #
#  then this script would not function properly as this routine is not an end-all.                     #
#  For DDL/DML: free style allowed. i.e. all in one line or over several lines                         #
#  For PL/SQL: BEGIN and END must be by itself on its own line. Do not cram everything on one line as  #
#  that is bad practise which is difficult to read and is un-structured.                               #
# Special Note:                                                                                        #
#  This scripts works on a pre-defined set of SQL commands, and so if something is not defined then    #
#  it will not look for it and it will be missed. The new command must be coded into it.               #
#  External procedure/function are currently not in scope, for example:                                #
#     CREATE PROCEDURE xyz ( x IN REAL )                                                               #
#            IS LANGUAGE C NAME c_xyz LIBRARY c_utils PARAMETERS ( x BY REFERENCE );                   #
#  See variables: $DDL, $DML, and $PLSQL for a list of what are defined.                               #
# About Oracle DDL, DML, and PL/SQL and how this script works with them:                               #
#  There are three variables: $DDL, $DML, and $PLSQL which contain basic syntax for the statements     #
#  for example, CREATE TABLE is a part of $DDL, just like INSERT is a part of $DML, while              #
#  CREATE PROCEDURE is a part of $PLSQL. While $DML and $PLSQL are fairly complete meaning most of the #
#  statments are covered, $DDL are not because there are way too many DDL statements out there and     #
#  that many are not likely to be used in a sql script. For example, one would not likely to construct #
#  scripts to handle flashback database, but instead, run the commands in SQL*Plus on an ad-hoc basis. #
#  Since "flashback database" is not part of $DDL, then the routine would bypass it altogether.        #
#  i.e. it would not even check for whether it is ended with ";".  On the other hand since "REVOKE"    #
#  is defined withina $DDL then the script would check for ";" when it comes across "REVOKE"...        #
#  Additionally, there is a routine called "chk_schema_name_before_object". if, for example, INSERT    #
#  is defined in it, then it would check for whether the object (table in this case) is preceded by    #
#  schema name. Although "REVOKE" is a part of $DDL, but due to the fact that it is not defined in     #
#  that routine, then no check would be made for schema name before object for REVOKE. Afterall,       #
#  one would not normally need to check that as REVOKE is applicable to a privilege, not table or      #
#  other object names.  There is another routine called "chk_schema_name_before_PLSQL_object" but that #
#  is used for dealing with PL/SQL objects such as PROCEDURE, FUNCTION, TRIGGER, TYPE and it contains  #
#  chedk for one type of statement, for example, "create or replace procedure...".                     #
# *Therefore, if a new DDL is to be checked, then it must be included in $DDL at the very least.       #
#  This way the basic ";" would be checked. Next, decide whether schema name preceding object is to be #
#  checked. If so, the it must be coded within "chk_schema_name_before_object".                        #
# Revisions:                                                                                           #
# Nov 16, 2023 LHo  still in beta                                                                      #
# Mar 1, 2024  LHo  gen code review, esp. repl `` with $()                                             #
########################################################################################################
## To turn debug on set debug="Y", to turn off, set debug=""                                           #
debug="Y"                                                                                              #
########################################################################################################
full_scriptname=$(realpath -s "$0") # this is added to address running as "./" issue.
scriptdir=$(dirname $full_scriptname)
scriptname=$(basename $full_scriptname)
deploy_base_path="/as_shared/database"
TODAY=$(date +%Y%m%d-%H%M%S)
logdir="$(dirname $scriptdir)/logs"
logfile="$logdir/${scriptname%.*}_${TODAY}.log"

if [[ $# -ne 1 ]]; then
  echo -e "\n\033[37;1m$scriptname\033[0;39m (β) takes a file (containing list of SQL scripts) as parameter, or"
  echo    " interactively, line-by-line, SQL scripts, and produces a report on the following:"
  echo    "  1. missing or misplaced \";\""
  echo    "  2. missing, misuse, or misplaced \"/\""
  echo    "  3. missing or misuse of \"END\" at end of PL/SQL"
  echo    "  4. schema user attached to (precedes) object names"
  echo    " The session is captured in log file: \"$logdir/${scriptname%.*}_YYYYMMDD-hhmiss.log\""
  echo    " Any errors produced from the checks are reported in a report file."
  echo -e "\n\033[37;1m✽Note: this script is not designed to check the full syntax of all of the statements!"
  echo -e "       i.e. it will not notify you of any typos as it's beyond the scope of the script.\033[0;39m"
  echo    " See log file for the name of the report file, if produced. No report means no errors."
  echo    "✽At times, due to some file having been transferred from a PC, the report might complain about,"
  echo    " for example, a missing slash, even though it's there. Deleting the line and adding it back could resolve it."
  echo    " It is best to run this again after the errors are fixed just to be sure all errors had been addressed."
  echo -e "\nUsage: \033[37;1m$scriptname {file_containing_list_of_scripts}\033[0;39m"
  echo -e " e.g.: \033[37;1m$scriptname /u01/db_objs_list.txt\033[0;39m"
  echo    " note: the files referenced in the list of scripts are saved under the base directory \"$deploy_base_path\""
  echo    "       meaning that if you have \"view/CR_ABC.sh\" listed in the file then the script is actually located"
  echo    "       at \"$deploy_base_path/view/CR_ABC.sh\""
  echo -e "       comment lines starting with # are allowed and will be ignore\n"
  echo    " ... alternatively, one can enter script via stdin from terminal instead of file, this is useful"
  echo    " if you have scripts outside the base directory, then you should enter them from standard input"
  echo -e "       \033[37;1mcat - | [./]$scriptname -\033[0;39m  ← note cat is just one example of input"
  echo    "       <enter path and name of script - press ENTER to continue next line>"
  echo    "       <enter CTRL-D to signal end of input>"
  echo -e " e.g.: \033[37;1mcat - | ./$scriptname -\033[0;39m"
  echo    "       data/create_data.sql          ← will look into base directory for the file"
  echo    "       /u02/scripts/creat_tables.sql ← file located outside of base directory"
  echo -e "       ^D                            ← <Ctrl-D> to end input\n"
  [[ ! -z "$debug" ]] && echo -e "\n✋Debug is currently ON, to turn off, edit script and change debug=\"\"\n"
  [[ ! -d "$deploy_base_path" ]] && echo "Attn: base directory for holding sql scripts for deployment, \"$deploy_base_path\", does not exist - please set up if you want to use file containing list of SQL scripts."
  [[ ! -d "$logdir" ]] && echo "Attn: directory for holding logs for this script, \"$logdir\", does not exist - please set up."
  exit 0
fi

obj_list_file="$1"

## the previously defined log file captures the session, while
## the rptfile captures any errors resulting from the checks, no file produced means no error.
rptfile="$logdir/${scriptname%.*}_${TODAY}.rpt"

if [[ "$obj_list_file" != "-" ]]; then
  [[ ! -d "$deploy_base_path" ]] && echo "Error: the base directory for holding SQL scripts, \"$deploy_base_path\", does not exist!"|tee -a $logfile && exit 1
 else
  obj_list_file="/dev/stdin"
fi

## -e below test incl non-regular files
[[ ! -e "$obj_list_file" ]] &&
 echo "Error: cannot find file \"$obj_list_file\" containing list of scripts to deploy. Terminating."|tee -a $logfile &&
 exit 1

#coleurs
#utilisez 1m pour en gras, 0m pour normal, et 4m pour souligner
rouge="\033[31m"
bd_rouge="\033[31;1m"
bl_rouge="\033[31;5m"
rv_rouge="\033[31;7m"
vert="\033[32m"
bl_vert="\033[32;5m"
rv_vert="\033[32;7m"
jaune="\033[33m"
bl_jaune="\033[33;5m"
rv_jaune="\033[33;7m"
bleu="\033[34m"
bl_bleu="\033[34;5m"
rv_bleu="\033[34;7m"
violet="\033[35m"
bl_violet="\033[35m"
rv_violet="\033[35m"
cyan="\033[36m"
bl_cyan="\033[36m"
rv_cyan="\033[36m"
blanc="\033[37m"
bl_blanc="\033[37m"
rv_blanc="\033[37m"
normal="\033[0;39m"

#--------------------------------------------------------------------------------------------
# variable DDL contains a list of DDL. They only need to be ended (and run) by a single ";" |
# note: there's a space behind ^EXEC in order to distinguish it from "EXECUTE IMMEDIATE"    |
#--------------------------------------------------------------------------------------------
DDL="^ALTER|^CALL|^COMMENT|^CREATE|^DROP|^EXEC |^GRANT|^RENAME|^REVOKE|^TRUNCATE"

#--------------------------------------------------------------------------------------------
# variable DML contains a list of DML. They only need to be ended (and run) by a single ";" |
# Note: SELECT is not part of variable DML by design                                        |
#--------------------------------------------------------------------------------------------
DML="^COMMIT|^DELETE|^INSERT|^LOCK TABLE|^MERGE|^ROLLBACK|^SAVEPOINT|^UPDATE|^WITH"

#--------------------------------------------------------------------------------------------------------------
# variable PLSQL has "^DECLARE", "^BEGIN" excluded by design                                                  |
# It contains syntax for PL/SQL that require both "END;" (to end the block except for TYPE) AND "/" to run it |
#--------------------------------------------------------------------------------------------------------------
PLSQL="^CREATE (OR REPLACE )?((NON)?EDITIONABLE )?(FUNCTION|PROCEDURE|TRIGGER|TYPE (BODY)?|PACKAGE (BODY)?)"

#=====================================================================================================
init_vars()
{
slash_star_comment="N"
line_num=0
begin_cnt=0
end_cnt=0
prt_sql_script=""
waiting_for_semicolon=""
waiting_for_slash=""
#third_last_line=""
#third_last_formatted_line=""
second_last_line=""
second_last_formatted_line=""
prev_line=""
prev_formatted_line=""
} # End of init_vars

#=====================================================================================================
save_lines()
{
#third_last_line="$second_last_line"
#third_last_formatted_line="$second_last_formatted_line"
second_last_line="$prev_line"
second_last_formatted_line="$prev_formatted_line"
prev_line="$line"
prev_formatted_line="$formatted_line"
} # End of save_lines

#=====================================================================================================
prt_error()
{
err_msg1="$1"
err_msg2="$2"
if [[ -z "$prt_sql_script" ]]; then
  prt_sql_script="$full_sql_script_name"
  echo -e "$vert┌$(printf '─%.0s' $(seq 1 $((${#prt_sql_script}+6))))┐"|tee -a $rptfile
  echo    "│   $prt_sql_script   │"|tee -a $rptfile
  echo -e "└$(printf '─%.0s' $(seq 1 $((${#prt_sql_script}+6))))┘$normal"|tee -a $rptfile
fi
[[ ! -z "$err_msg1" ]] && echo -e "$err_msg1"|tee -a $rptfile
[[ ! -z "$err_msg2" ]] && echo -e "$err_msg2"|tee -a $rptfile
} # End of prt_error

#=====================================================================================================
chk_schema_name_before_PLSQL_object()
{
#[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_PLSQL_object.">>$logfile
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create (or replace )?((non)?editionable )?(function|procedure|trigger|type (body)?|package (body)?)') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized PL/SQL is 'create [or replace] function, procedure, trigger, type (body), package (body)'.$normal\n">>$logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '(package( body)?|type( body)?|trigger|procedure|function)\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name"  ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR001 Warning on line $line_num: schema name found on PL/SQL object \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))PL/SQL is not 'create [or replace] function, procedure, trigger, type (body), package (body)'.">>$logfile
} # End of chk_schema_name_before_PLSQL_object

#=====================================================================================================
chk_schema_name_before_object()
## This SR is common for both DDL and DML objects
## Note: not all commands from $DDL and $DML variables are defined here,
##  for example "exec ", "grant", "revoke".
##  the list of DDL is also not complete.  They might be added later on based on need.
## Note: the following order is important - not arbitrary - do NOT re-arrange!
##  They are order by how likely the statements are to occur. i.e. the 1st command is placed first because
##  it is deemed to occurred more often than the others.
{
#[[ "$debug" = "Y" ]] && echo -e "\nline $line_num: calling SR chk_schema_name_before_object.">>$logfile

## (1) INSERT INTO <table>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'insert (.*)?into ') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'insert into'.$normal\n">>$logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'into\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR101 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'insert into'.">>$logfile

## (2) UPDATE <table>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'update (.*)?') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'update'.$normal\n">>$logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '.*?(?=SET)'|tr -s " "|rev|awk '{print $1}'|rev|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR102 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'update'.">>$logfile

## (3) DELETE FROM <table>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'delete (.*)?from ') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'delete'.$normal\n">>$logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'from\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.') # tr -d \ used to be \\
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR103 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'delete'.">>$logfile

## (4) CREATE table <table>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create (shared |duplicated |(immutable )?(blockchain )?|(global|private)( temporary )?)?table') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'create table'.$normal\n">>$logfile
  # note "grep -owiP" below the extra "w" is needed due to the existence of "immutable" which blends with "table" and if not there then grep not work correctly.
  full_obj_name=$(echo "$formatted_line"|grep -owiP 'table\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR104 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'create table'.">>$logfile

## (5) CREATE view <view>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create (or replace )?((no )?force )?((editionable )?(editioning )?|(noneditionable )?)?view') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'create view'.$normal\n">>$logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'view\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR105 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'create view'.">>$logfile

## (6) CREATE <index, materialized view, sequence>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create ((unique |bitmap )?index|materialized view|sequence)') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'create index, materialized view, sequence'.$normal\n">>$logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '(index|materialized view|sequence)\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR106 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'create index, materialized view, sequence'.">>$logfile

## (7) DROP <table, view, materialized view, trigger, procedure, function, type, type body, package, package body,
##           index, indextype, sequence, synonym>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'drop (table|(materialized )?view|trigger|procedure|function|type( body)?|package( body)?|index(type)?|sequence|(public )?synonym)') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'drop table, view, materialized view, trigger, procedure, function,">> $logfile
  [[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+24))))type (body), package (body), index(type), sequence, synonym'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '(table|view|package( body)?|trigger|procedure|function|type( body)?|index|sequence|synonym)\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR107 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'drop table, view, materialized view, trigger, procedure, function,">> $logfile
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+24))))type (body), package (body), index(type), sequence, synonym'.">> $logfile

## (8) ALTER <table, sequence, view, materialized view, materialized view log, synonym, trigger, type, function,
##            index, indextype, package, procedure, dimension, java, library, operator>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'alter (table|(materialized )?view|(public )?synonym|sequence|trigger|type|function|index|package|procedure|dimension|java|library|operator)') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'alter table, sequence, view, materialized view (log), synonym, trigger, type,">> $logfile
  [[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+25))))function, index(type), package, procedure, dimension, java, library, operator'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '(table|view|materialized view log|sequence|synonym|trigger|type|function|index|package|procedure|dimension|java (source|class)|library|operator)\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR108 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'alter table, sequence, view, materialized view (log), synonym, trigger, type,">> $logfile
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+25))))function, index(type), package, procedure, dimension, java, library, operator'.">> $logfile


## (9) COMMENT ON <column, indextype, materialized view, mining model, operator, table>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'comment on (|column|indextype|materialized view|mining model|operator|table)') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'comment on'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '(column|indextype|materialized view|mining model|operator|table)\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR109 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'comment on'.">> $logfile

## (10) LOCK <TABLE>, TRUNCATE <TABLE>
if [[ ! -z $(echo "$formatted_line"|grep -Ei '(lock|truncate) table') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'lock table' or 'truncate table'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'table\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR110 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is neither 'lock table' nor 'truncate table'.">> $logfile

## (11) MERGE INTO <table>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'merge (.*)?into ') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'merge'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'into\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR111 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'merge'.">> $logfile

## (12) RENAME <table>; note: "rename column" is excluded because it is part of "alter table..."
if [[ ! -z $(echo "$formatted_line"|grep -Eiv 'rename column'|grep -Ei 'rename') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'rename <table>'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP '\w+\K.*\s+(?=to)'|tr -d \"|grep -ow '\w*\.\w*') $(echo "$formatted_line"|grep -oiP 'to\s+\K.*\w+'|tr -d \"|grep -ow '\w*\.\w*')
  full_obj_name=$(echo "$full_obj_name"|sed 's/^[[:blank:]]*//'|sed 's/[[:blank:]]*$//')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR112 Warning on line $line_num: schema name(s) found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'rename <table>'.">> $logfile

## (13) CREATE synonym <synonym>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create (or replace )?((non)?editionable )?(public )?synonym') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'create synonym'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'synonym\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR113 Warning on line $line_num: schema name found on \"$full_obj_name\".$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'create synonym'.">> $logfile

## (14) CREATE database link <db_link>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create (shared )?(public )?database link') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'create database link'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'link\s+\K.*\w+'|tr -d \"|awk '{print $1}'|grep '\.')
  [[ ! -z "$full_obj_name" ]] &&
   prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$jaune*** SR114 Warning on line $line_num: \".\" found on database link \"$full_obj_name\"." &&
   prt_error "" "    Although allowed, it might not be best practise. Please change.$normal\n"
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'create database link'.">> $logfile

## (15) CREATE directory <directory>
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'create (or replace )?directory') ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized SQL is 'create directory'.$normal\n">> $logfile
  full_obj_name="`echo "$formatted_line"|grep -oiP 'directory\s+\K.*\w+'|tr -d \\"|awk '{print $1}'|grep '\.'`"
##  directory=$(echo "$line"|grep -oiP 'as\s+\K.*\w+'|tr -d \\')
  directory=$(echo "$line"|grep -oiP 'as\s+\K.*\w+'|tr -d \')
  if [[ ! -z "$full_obj_name" ]]; then
    prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rouge*** SR115 Error on line $line_num: \".\" found on directory \"$full_obj_name\"."
    prt_error "    This will trigger an ORA-00905 error."
    [[ ! -d "$directory" ]] && prt_error "    SR116 Error on line $line_num: Directory \"$directory\" does not exist."
    prt_error "" "$normal\n"
   else
    [[ ! -d "$directory" ]] && prt_error "$line_num: $line" "$rouge*** SR116 Error on line $line_num: Directory \"$directory\" does not exist.$normal\n"
  fi
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))SQL is not 'create directory'.">> $logfile

## "exec ", "grant", "revoke", and others that do not reference schema name are obviously not addressed here.
} # End of chk_schema_name_before_object

#=====================================================================================================
chk_schema_name_after_keyword_FROM()
{
# below comparison checks if the DML is not a DELETE statment as it is handled elsewhere
# and that the word "FROM", if exists, is not part of a quoted string
#[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM.">>$logfile
if [[ ! -z $(echo "$formatted_line"|grep -Ei 'from') && -z $(echo "$formatted_line"|grep -Ei '^delete (.*)?from') && -z $(echo "$formatted_line"|grep -Ei "'.*from.*'") ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized line containing keyword 'FROM' and is not part of 'DELETE'.$normal\n">> $logfile
  full_obj_name=$(echo "$formatted_line"|grep -oiP 'from\s+\K.*\w+'|tr -d \"|grep -ow '\w*\.\w*'|xargs)
  if [[ ! -z "$full_obj_name" ]]; then
    [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
    prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
    prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$violet** SR201 Warning on line $line_num: schema name found on object(s) \"$full_obj_name\" after keyword \"FROM\".$normal\n"
  fi
  return
fi
[[ "$debug" = "Y" ]] && echo "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))line does not contain keyword 'FROM'.">> $logfile
} # End of chk_schema_name_after_keyword_FROM

#=====================================================================================================
ignore_comments()
{
# chk for /* ... */ comment on same line
[[ ! -z "`echo "$formatted_line"|grep "^/\*"`" ]] &&
[[ ! -z "`echo "$formatted_line"|grep "\*/$"`" ]] && continue
# chk for /* ... */ comment spanning more than one line
if [[ "$slash_star_comment" = "Y" ]]; then
  [[ ! -z $(echo "$formatted_line"|grep "\*/$") ]] && slash_star_comment="N"
  continue
 else
  [[ ! -z $(echo "$formatted_line"|grep "^/\*") ]] && slash_star_comment="Y" && continue
fi
# chk for -- and REM at beginning of line
[[ ! -z $(echo "$formatted_line"|grep -E "^--|^REM") ]] && continue
} # End of ignore_comments

#=====================================================================================================
#=====================================================================================================
chk_PLSQL_block()
{
[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_PLSQL_block.">>$logfile
if [[ ! -z $(echo "$formatted_line"|grep -E "$PLSQL|^DECLARE|^BEGIN") ]]; then
 # new line with "CREATE or REPLACE procedure/function/trigger/type" or "DECLARE" found
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized line containing beginning of PL/SQL, such as \"create or replace...\", \"DECLARE\", or \"BEGIN\".$normal\n">> $logfile
  if [[ -z "$waiting_for_slash" ]]; then
   # and no previous unfinished PL/SQL found, this is newly found PL/SQL line.
    if [[ "$waiting_for_semicolon" = "Y" ]]; then
     # Previous unfinished DDL/DML found
      [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
      prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
      prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan** SR301 Error before line $line_num: expecting \";\" to complete the previous SQL.$normal\n"
      waiting_for_semicolon=""
    fi
   else
    # waiting_for_slash != "" : prev. unfinished PL/SQL detected
#    if [[ ! -z "`echo "$formatted_line"|grep -E "$PLSQL|^DECLARE"`" ]]; then
#     # below is only applicable to PLSQL & DECLARE but not anon PL/SQL (start with BEGIN) because it could be part of PL/SQL or DECLARE
    if [[ ! -z $(echo "$formatted_line"|grep -E "$PLSQL") ]]; then
     # below is only applicable to PLSQL but not anon PL/SQL (start with DECLARE or BEGIN) because it could be part of PL/SQL
      [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
      prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
      prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan** SR302 Error before line $line_num: expecting \"/\" to complete the previous PL/SQL.$normal\n"
    fi
  fi
  # after checking the two flags to realize if any prev stmt outstand, still this is new line for PL/SQL or DECLARE that is found.
  [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_PLSQL_object from inside chk_PLSQL_block.">>$logfile
  chk_schema_name_before_PLSQL_object
  if [[ ! -z $(echo "$formatted_line"|grep -E "^BEGIN") ]]; then
    ((begin_cnt++))
    waiting_for_slash="A"
   else
    [[ ! -z $(echo "$formatted_line"|grep -E " TYPE ") ]] && waiting_for_slash="T" || waiting_for_slash="Y"
  fi
  save_lines
  continue
fi
[[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))bypass main body of SR chk_PLSQL_block...\n">>$logfile
} # End of chk_PLSQL_block

##====================================================================================================
chk_DDL_DML()
{
## Look for start of DDL or DML statements defined by $DDL, $DML, and SELECT
## Rules and standards for DDL/DML statements:
## at the first sign of a blank line, the DDL/DML statement is considered complete.
## Although SQL*plus does allow blank lines (when SQLBL is set to ON) this script will simply
## enforce the idea that DDL/DML must not contain blank lines.
[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_DDL_DML.">>$logfile
if [[ ! -z $(echo "$formatted_line"|grep -E "$DDL|$DML|^SELECT") ]]; then
  [[ "$debug" = "Y" ]] && echo -e "$violet$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))recognized line containing beginning of DDL or DML.$normal\n">> $logfile
 # new line with DDL/DML found...
  if [[ -z "$waiting_for_semicolon" ]]; then
   # this is new DDL/DML line as no previous DDL/DML pending - waiting_for_semicolon=""
    if [[ ! -z "$waiting_for_slash" ]]; then
     # prev PL/SQL seem to be unfinished, waiting_for_slash is not blank
      if [[ ! -z $(echo "$formatted_line"|grep -E "$DML|^EXECUTE IMMEDIATE|^SELECT") ]]; then
       # EXECUTE IMMEDIATE and other DMLs (incl SELECT) can be part of PL/SQL
       # chk if DML is in between BEGIN/END of PL/SQL that is assumed to be unfinished
       # DML such as SELECT can be in the declaration section before the 1st BEGIN
        if [[ $((begin_cnt)) -lt 1 || $((begin_cnt)) -gt $((end_cnt)) ]]; then
#          if [[ ! -z "`echo "$formatted_line"|grep -E "^SELECT|\(SELECT|\( SELECT"`" ]]; then
#          if [[ ! -z "`echo "$formatted_line"|grep -E "SELECT"`" ]]; then
          if [[ ! -z $(echo "$formatted_line"|grep -Ei "SELECT") && -z $(echo "$formatted_line"|grep -Ei "'.*select.*'") ]]; then
            [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM(1) from inside chk_DDL_DML.">>$logfile
            chk_schema_name_after_keyword_FROM
           else
            [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_object(1) from inside chk_DDL_DML.">>$logfile
            chk_schema_name_before_object
          fi
         else
          [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
          prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
          prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan** SR401 Error before line $line_num: expecting \"/\" to complete the previous PL/SQL.$normal\n"
          waiting_for_slash=""
        fi
       else
       # No DDL/DML dectected
       # previous stmt was PL/SQL that has not yet ended
        [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
        prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
        prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan** SR402 Error before line $line_num: expecting \"/\" to complete the previous PL/SQL.$normal\n"
        waiting_for_slash=""
      fi
     else
     # waiting_for_slash = "" ; no prev PL/SQL and DDL/DML pending
      if [[ -z $(echo "$formatted_line"|grep -E "^SELECT") ]]; then
        [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_object(2) from inside chk_DDL_DML.">>$logfile
        chk_schema_name_before_object
       else
        [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM(2) from inside chk_DDL_DML.">>$logfile
        chk_schema_name_after_keyword_FROM
      fi
    fi
   else
    # previous DDL/DML pending - waiting_for_semicolon="Y"
    if [[ ! -z $(echo "$formatted_line"|grep -E "$DDL|$DML") ]]; then
      [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
      prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
      prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan** SR403 Error before line $line_num: expecting \";\" to complete the previous SQL.$normal\n"
    fi
    if [[ -z $(echo "$formatted_line"|grep -E "^SELECT") ]]; then
      [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_object(3) from inside chk_DDL_DML.">>$logfile
      chk_schema_name_before_object
     else
      [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM(3) from inside chk_DDL_DML.">>$logfile
      chk_schema_name_after_keyword_FROM
    fi
  fi # waiting_for_semicolon Y/N
 # check if ; is on the same line
  [[ -z $(echo "$formatted_line"|grep -E ";$") && -z "$waiting_for_slash" ]] && waiting_for_semicolon="Y" || waiting_for_semicolon=""
  save_lines
  continue
fi # new DDL/DML
[[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))bypass main body of SR chk_DDL_DML...\n">>$logfile
} # End of chk_DDL_DML

#=====================================================================================================
# Unfinished or on-going statements
#=====================================================================================================
chk_unfinished_PLSQL()
{
[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_unfinished_PLSQL.">>$logfile
#if [[ "$waiting_for_slash" = "Y" || "$waiting_for_slash" = "A" || "$waiting_for_slash" = "T" ]]; then
if [[ ! -z "$waiting_for_slash" ]]; then
  [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_PLSQL_object(1) from inside chk_unfinished_PLSQL.">>$logfile
  chk_schema_name_before_PLSQL_object
  [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM(1) from inside chk_unfinished_PLSQL.">>$logfile
  chk_schema_name_after_keyword_FROM
  # does line contain "/", if so check if previous line is "END;", if so reset flags and continue loop
  if [[ ! -z $(echo "$formatted_line"|grep -E "^/$") ]]; then
   # line now only contains /
    if [[ -z "$prev_formatted_line" ]]; then
     # previous line is blank
      [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
      prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
      prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$violet** SR501 Error on line $((line_num-1)): line before "/" should not be blank.$normal\n"
     else
      if [[ "$waiting_for_slash" = "T" ]]; then
        # special case for "TYPE"... check if prev line starts with END
        if [[ ! -z $(echo "$prev_formatted_line"|grep -Ei "^END") ]]; then
         # END found
          [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
          prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
          prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$violet** SR502 Error: found \"END\" on line $((line_num-1)), TYPE definition does not end with \"END\".$normal\n"
         else
         # END not found, but now check for ";" either by itself or at end of line
          if [[ -z $(echo "$prev_formatted_line"|grep -E "^;$|;$") ]]; then
           # ";" not found either by itself or at end of line
            [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
            prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
            prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$violet** SR503 Error on line $((line_num-1)): missing \";\", line must contain \";\" by itself or ends with it.$normal\n"
          fi
        fi
       else # all other PL/SQL such as procedure, function, and trigger, but not TYPE
        if [[ ! -z $(echo "$prev_formatted_line"|grep -Ev "^END (IF|CASE|LOOP)") ]]; then
         # line now either contains END or no END, but definitely no END (IF|CASE|LOOP)
          if [[ -z $(echo "$prev_formatted_line"|grep -E "^END") ]]; then
            [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
            prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" "$violet** SR504 Error at line $((line_num-1)): Missing \"END;\"$normal."
            prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "\n"
           else
            if [[ -z $(echo "$prev_formatted_line"|grep -oiP "END\K.*"|grep ";") ]]; then
              [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
              prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" "$violet** SR505 Error on line $((line_num-1)): Missing \";\" after \"END\".$normal"
              prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "\n"
            fi
          fi
         else
          [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
          prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" "$violet** SR506 Error on line $((line_num-1)): incorrect type of \"END\" encountered.$normal"
          prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "\n"
        fi
      fi
    fi
    waiting_for_slash=""; begin_cnt=0; end_cnt=0
   else # / not found and so PL/SQL is still underway (not finished)
    [[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))/ not found, PL/SQL is still underway.">>$logfile
    # other lines to chk are: is line DML or BEGIN or END ?
    if [[ ! -z $(echo "$formatted_line"|grep -E "$DML|^EXECUTE IMMEDIATE") ]]; then
     # test if this DML is part of PL/SQL or new (outside of the current PL/SQL)
      if [[ $((begin_cnt)) -gt $((end_cnt)) ]]; then
        [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_before_object(2) from inside chk_unfinished_PLSQL.">>$logfile
        chk_schema_name_before_object
        [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM(2) from inside chk_unfinished_PLSQL.">>$logfile
        chk_schema_name_after_keyword_FROM
       else
        [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
        prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
        prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan** SR507 Error before line $line_num: expecting \"/\" to complete the previous PL/SQL.$normal\n"
      fi
     else
      # keep track of BEGIN/END so that test can be done for DML found within PL/SQL (validate if part of PL/SQL or new DML)
      [[ ! -z $(echo "$formatted_line"|grep -E "^BEGIN") ]] && ((begin_cnt++))
      [[ ! -z $(echo "$formatted_line"|grep -Ev "END (IF|CASE|LOOP)"|grep -E "^END") ]] && ((end_cnt++))
      [[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))BEGIN count: $begin_cnt; END count: $end_cnt">>$logfile
    fi
  fi
  save_lines
  continue
fi
[[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))bypass main body of SR chk_unfinished_PLSQL...\n">>$logfile
} # End of chk_unfinished_PLSQL

#=====================================================================================================
chk_unfinished_DDL_DML()
{
[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_unfinished_DDL_DML.">>$logfile
if [[ "$waiting_for_semicolon" = "Y" ]]; then
  [[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_schema_name_after_keyword_FROM from inside chk_unfinished_DDL_DML.">>$logfile
  chk_schema_name_after_keyword_FROM
  if [[ ! -z $(echo "$formatted_line"|grep -E "^;") ]]; then
   # found ; - multi-line DDL/DML now ended
    if [[ -z "$prev_formatted_line" ]]; then
     # previous line is blank
      [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
      prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" "$cyan*** SR601  Error on line $((line_num-1)): line before ";" should not be blank.$normal"
      prt_error "$line_num: line" "\n"
    fi
    waiting_for_semicolon=""
    save_lines
    continue
  fi
  if [[ ! -z $(echo "$formatted_line"|grep -E "^/") ]]; then
   # found / instead of ; but still multi-line DDL/DML now ended - should always use ; instead of /
    [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
    prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
    prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan*** SR602 Warning on line $line_num: expecting \";\" but found \"/\" instead."
    prt_error "" " ● Best practise to use \";\" to end SQL in order to be consistent.$normal\n"
    waiting_for_semicolon=""
    save_lines
    continue
  fi
  # not blank line and not start of DDL/DML
  if [[ ! -z $(echo "$formatted_line"|grep -E ";$") ]]; then
   # line ends with ;
    waiting_for_semicolon=""
    save_lines
    continue
  fi
  if [[ -z "$formatted_line" ]]; then
   # line is blank
    [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
    prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
    prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$cyan*** SR603 Error on or before line $line_num: expecting \";\" but found blank line instead.$normal\n"
    waiting_for_semicolon=""
    save_lines
    continue
  fi
fi
[[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))bypass main body of SR chk_unfinished_DDL_DML...\n">>$logfile
} # End of chk_unfinished_DDL_DML

#=====================================================================================================
chk_when_no_PLSQL_or_DDL_DML_pending()
{
[[ "$debug" = "Y" ]] && echo "line $line_num: calling SR chk_when_no_PLSQL_or_DDL_DML_pending.">>$logfile
if [[ ! -z $(echo "$formatted_line"|grep -E "^/$") ]]; then
  [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
  prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
  prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rv_rouge*** SR700 Error on line $line_num: found \"/\" when no PL/SQL is pending.$normal"
  prt_error "" " ${bd_rouge}● DANGER! The extra \"/\" will re-run the last SQL or PL/SQL.$normal\n"
 else
  if [[ ! -z $(echo "$formatted_line"|grep -E "^;$") ]]; then
    [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
    prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
    prt_error "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line" "$rv_rouge*** SR701 Error on line $line_num: found orphaned \";\" does not seem to be part of previous SQL.$normal"
    prt_error "" " ${bd_rouge}● Either truly orphaned or possible blank space after the end of previous SQL.$normal\n"
  fi
  return
fi
[[ "$debug" = "Y" ]] && echo -e "$(printf ' %.0s' $(seq 1 $((${#line_num}+7))))bypass main body of SR chk_when_no_PLSQL_or_DDL_DML_pending...\n">>$logfile
}

#=====================================================================================================
find_where_and_which_scripts_to_run()
{
# due to the fact that there are two distinct ways to run SQL scripts,
# 1) via the input file where the various scripts are listed, and
# 2) via standard input where one can list scripts line by line, and done with Ctrl-D
# this routine determins where the scripts are to run from.
if [[ "$obj_list_file" != "/dev/stdin" ]]; then
  # the leading "/" is removed
  sql_script="`printf '%s\n' "${sql_script#"${sql_script%%[[:alpha:]]*}"}"`"
  # remove the leading "database/" if it exists
#  sql_script="`echo $sql_script|sed -e 's/^database\///'`"
  sql_script=$(echo $sql_script|sed -e 's/^database\///')
  full_sql_script_name="$deploy_base_path/$sql_script"
 else
  # input is NOT from object list file
  # check if file is entered is such a way that it still can be found in the base directory
  if [[ -f "$deploy_base_path/$sql_script" ]]; then
    full_sql_script_name="$deploy_base_path/$sql_script"
    echo "\"$sql_script\" found under \"$deploy_base_path\" while entering from standard input."|tee -a $logfile
   else
    full_sql_script_name="$sql_script"
  fi
fi
}

#######################################################################
##################            MAIN BLOCK            ###################
#######################################################################
[[ "$obj_list_file" = "/dev/stdin" ]] && echo -e "$scriptname is running using input from \"/dev/stdin\"."|tee -a $logfile
while IFS=$'\t' read -r sql_script ; do
   # skip comments
#   [[ "`echo "$sql_script"|sed 's/^[[:blank:]]*//' |grep "^#"`" != "" ]] && continue
   [[ ! -z $(echo "$sql_script"|sed 's/^[[:blank:]]*//'|grep "^#") ]] && continue
   find_where_and_which_scripts_to_run
   [[ ! -f "$full_sql_script_name" ]] &&
     echo -e "\nWarning: \"$full_sql_script_name\" does not exist - skipping."|tee -a $logfile && continue
## script exists - process it line by line
   echo -e "\n$vert★★ Commenced processing \"$full_sql_script_name\"$normal\n"|tee -a $logfile
   init_vars
## the IFS=$'\r' helps to get rid of the hidden ^M, without it, manipulating the line gives upredictable result.
   while IFS=$'\r\t' read -r line; do
    ((line_num++))
   # trim out spaces in front, behind, and multiple spaces in between, and make all UC
    formatted_line="`echo "$line"|sed 's/^[[:blank:]]*//'|sed 's/[[:blank:]]*$//'|tr -s " "|tr '[a-z]' '[A-Z]'`"
    ignore_comments
    echo "$line_num: $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$line"
#    echo "$line_num: $line"

#### ################################################################## ####
### check PL/SQL first and then DDL/DML: Do NOT change order of checking ###
#### ################################################################## ####
 ## (1) Check line for first occurrence of CREATE or REPLACE style of PL/SQL, or start with DECLARE, or with BEGIN
  # does line start with PL/SQL such as "CREATE PROCEDURE"? (.. FUNCTION, TRIGGER, TYPE), or DECLARE, or BEGIN
    chk_PLSQL_block

 ## (2) Check line for first occurence of DDL/DML statement as defined in variables $DDL and $DML incl SELECT
  # does line start with a DDL or DML (incl. SELECT)?
    chk_DDL_DML

### Here, at this point, the lines are neither the beginning of CREATE or REPLACE, DECLARE, BEGIN
 ## nor any DDL/DML, but rather their subsequent lines, or other unrelated lines.
  # There are two flags to watch for: waiting_for_semicolon=["Y",""] and waiting_for_slash=["Y","T","A",""]
  # "T" is for "TYPE" which is a special case of PL/SQL where it does not end with "END;"
  # "A" is for flagging simple anonymous PL/SQL block (starts with BEGIN)

 ## (3) Check line for subsequent/in-progress PL/SQL lines: waiting_for_slash="Y" or "T" or "A"
    chk_unfinished_PLSQL

 ## (4) check for subsequent/in-progress DDL/DML SQL lines: waiting_for_semicolon="Y"
    chk_unfinished_DDL_DML

 ## (5) at this point, no PL/SQL or SQL pending: waiting_for_slash="" & waiting_for_semicolon=""
    chk_when_no_PLSQL_or_DDL_DML_pending

    save_lines
   done < "$full_sql_script_name"
   # situation where SQL or PL/SQL not ended at the very last line of the script
   # here, $line had been reinitialized, must used the saved line $prev_line
   if [[ ! -z "$waiting_for_semicolon" ]]; then
     [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
     prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
     prt_error "$((line_num)): $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$prev_line" "$cyan*** MB001 Error $([[ -z "$prev_line" ]]&&echo "on"||echo "after") line $((line_num)): expecting \";\" to complete the current SQL.$normal\n"
   fi
   if [[ ! -z "$waiting_for_slash" ]]; then
     [[ ! -z "$second_last_formatted_line" ]] && prt_error "$((line_num-2)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-2)))))))$second_last_line" ""
     prt_error "$((line_num-1)): $(printf ' %.0s' $(seq 1 $((3-$(expr length $((line_num-1)))))))$prev_line" ""
     prt_error "$((line_num)): $(printf ' %.0s' $(seq 1 $((3-${#line_num}))))$prev_line" "$cyan*** MB002 Error $([[ -z "$prev_line" ]]&&echo "on"||echo "after") line $((line_num)): expecting \"/\" to complete the current PL/SQL.$normal\n"
   fi
   echo -e "$rouge★★ Completed processing \"$full_sql_script_name\".$normal"|tee -a $logfile
done <<< "$(< $obj_list_file )"
echo "The log file for the run is located at $logfile"
[[ ! -f $rptfile ]] && echo -e "\nNo errors found"|tee -a $logfile || echo -e "\nSee $rptfile for errors."|tee -a $logfile

