#!/bin/ksh

if [ $# -ne 1 ]
then
    echo "USAGE: $0 runsqlfile"
    exit 1
fi

database="PROD"
dbuser="apps"
dbpasswd="apps1234"
logdir="/home/mgldb/slc_tmp"
logfile="$logdir/slc_runsql.sh.log"
>${logfile}

runsqlfile=$1

spool_linesize="30000"
spool_long="999999"
spool_format="a50000"
run_flag="Y"

ECHO_SCREEN_LOG()
{
    echo "[$$] $*"
}

ECHO_ERROR_LOG()
{
    echo "[$$] $* "
}

SpoolSqlFileHead()
{
    if [ $# -ne 4 ]
    then
        ECHO_ERROR_LOG "USAGE: SpoolSqlFileHead ExeSqlFile Sqlfile_nm OnOffFlag TermOutFlag"
        ECHO_ERROR_LOG "    ExeSqlFile: SQL执行文件"
        ECHO_ERROR_LOG "    Sqlfile_nm: 输出文件"
        ECHO_ERROR_LOG "    OnOffFlag:  详细日志输出标志(on|off)"
        ECHO_ERROR_LOG "    TermOutFlag:终端输出标志(Y|N)"
        return 1
    fi

    ExeSqlFile=$1
    Sqlfile_nm=$2
    OnOffFlag=$3
    TermOutFlag=$4

    if [ "$OnOffFlag" != "on" -a "$OnOffFlag" != "off" ]
    then
        ECHO_ERROR_LOG "SpoolSqlFileHead OnOffFlag参数错误"
        return 1
    fi

    if [ "$TermOutFlag" = "Y" ]
    then
        term_out_flag="on"
    elif [ "$TermOutFlag" = "N" ]
    then
        term_out_flag="off"
    else
        ECHO_ERROR_LOG "SpoolSqlFileHead TermOutFlag参数错误"
        return 1
    fi

    cat >${ExeSqlFile} <<EOF
        WHENEVER OSERROR EXIT 255 ROLLBACK;
        WHENEVER SQLERROR EXIT 255 ROLLBACK;
        set sqlbl on;
        set define off;
        set pagesize 0;
        set termout ${term_out_flag};
        set echo ${OnOffFlag};
        set feedback ${OnOffFlag};
        set heading ${OnOffFlag};
        set trimout on;
        set trimspool on;
        set verify off;
        set linesize ${spool_linesize};
        set long ${spool_long};
        col c1 format ${spool_format};
        spool $Sqlfile_nm;
        EXECUTE DBMS_METADATA.SET_TRANSFORM_PARAM(DBMS_METADATA.SESSION_TRANSFORM,'SQLTERMINATOR',true);
EOF
}

SpoolSqlFileEnd()
{
    if [ $# -ne 1 ]
    then
        ECHO_ERROR_LOG "USAGE: SpoolSqlFileEnd ExeSqlFile"
        ECHO_ERROR_LOG "    ExeSqlFile: SQL执行文件"
        return 1
    fi

    ExeSqlFile=$1

    cat >>${ExeSqlFile} <<EOF
        spool off;
        quit;
EOF
}

LOGIN_STR="${dbuser}/${dbpasswd}@${database}"
ORACLE_USR=`echo ${dbuser}|tr [a-z] [A-Z]`
exesqlfile="$logdir/${runsqlfile}.exe.tmp"
tmpfile="$logdir/${runsqlfile}.spool.tmp"

SpoolSqlFileHead ${exesqlfile} ${tmpfile} on Y
if [ ! -f $runsqlfile ]
then
    ECHO_ERROR_LOG "ERROR: 文件[$runsqlfile]不存在"
    return 2
else
    cat $runsqlfile >> ${exesqlfile}
    echo "" >>${exesqlfile}
fi
SpoolSqlFileEnd ${exesqlfile}
sqlplus -L ${LOGIN_STR} @${exesqlfile}
if [ $? -ne 0 ]
then
    nflag=`grep -Ei 'CREATE  *|ALTER  *|DROP  *|COMMENT  *|TRUNCATE  *|GRANT  *|REVOKE  *|COMMIT *;|SAVEPOINT  *|ROLLBACK *;' "$runsqlfile"|wc -l`
    if [ $nflag -ne 0 ]
    then
        ECHO_ERROR_LOG "ERROR: 执行失败，检测到${runsqlfile}中存在DDL,DCL语句，需要人工回滚[${runsqlfile}]中的语句后才能重做"
    else
        ECHO_ERROR_LOG "ERROR: 执行失败，数据库自动回滚"
    fi
    return 2
else
    unknown_cnt=`grep "unknown command" ${tmpfile}|wc -l`
    if [ $unknown_cnt -ne 0 ]
    then
        ECHO_ERROR_LOG "WARNING: 存在unknown command"

        warn_cnt=`grep ^"0 rows " ${tmpfile}|wc -l`
        if [ $warn_cnt -ne 0 ]
        then
            ECHO_ERROR_LOG "WARNING: 执行结果存在 0 rows"
        fi
    fi
fi

rm ${exesqlfile}
rm ${tmpfile}
