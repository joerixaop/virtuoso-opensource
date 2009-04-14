#!/bin/sh
#
#  $Id$
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2009 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#

LOGFILE=../tpcw$2.output

if [ z$1 = zload ]
then
  rm -f tpcw_eb.db
  rm -f tpcw_eb.trx
  rm -f tpcw_eb.log
  rm -f tpcw_eb.bad 
  rm -f tpcw_eb.lck
fi

SRV=./virtuoso-t
SRV=virtuoso-t
export SRV

HOST_OS=`uname -s | grep WIN`
SILENT=${SILENT-0}
ISQL=isql
PORT=${PORT-1111}
HOST=${HOST-localhost}
HOST_OS=`uname -s | grep WIN`
DSN=$HOST:$PORT
HTTP=$HTTP_SERVER:$HTTP_PORT

if [ "x$HOST_OS" != "x" ] 
then
  SRV=../virtuoso-odbc-t.exe
fi

SERVER=$SRV
export SERVER
LOGIN="$PORT dba dba"
PORT1=`expr $PORT + 1`

if [ z$1 = zload ]
then
echo "
[Database]
DatabaseFile    = tpcw_eb.db
TransactionFile = tpcw_eb.trx
ErrorLogFile    = tpcw_eb.log
ErrorLogLevel   = 7
FileExtend      = 200
Striping        = 0
LogSegments     = 0
Syslog		= 0

;
;  Server parameters
;
[Parameters]
ServerPort           = $PORT1
ServerThreads        = 1000
CheckpointInterval   = 0
NumberOfBuffers      = 2000
MaxDirtyBuffers      = 1200
MaxCheckpointRemap   = 2000
UnremapQuota         = 0
AtomicDive           = 1
PrefixResultNames    = 0
CaseMode             = 2
DisableMtWrite       = 0
MaxStaticCursorRows  = 5000
AllowOSCalls         = 0
SQLOptimizer	     = 1

[Client]
SQL_QUERY_TIMEOUT  = 0
SQL_TXN_TIMEOUT    = 0
SQL_PREFETCH_ROWS  = 100
SQL_PREFETCH_BYTES = 16000

[AutoRepair]
BadParentLinks = 0
BadDTP         = 0

[Replication]
ServerName   = the_big_server
ServerEnable = 1
QueueMax     = 50000

" > tpcw_eb.ini

echo "
create procedure getURL() returns varchar
{
    return 'http://$HTTP/tpcw/html/';
}

create procedure starttpcw()
{
  declare LOG_LINE varchar;
  result_names (LOG_LINE);
  runShopping($NUMBER_ITEMS, $NUMBER_EBS);
}
" > SET_URL.sql

echo "
starttpcw();
" > RUN.isql
fi

LINE()
{
    ECHO "====================================================================="
}

ECHO()
{
    echo "$*"           | tee -a $LOGFILE
}

LOG ()
{
  echo $* >> $LOGFILE 
  echo $*
}

BANNER()
{
    ECHO ""
    LINE
    ECHO "=  $*"
    ECHO "= " `date`
    LINE
    ECHO ""
}

CHECK_LOG()
{
    passed=`grep "PASSED:" $LOGFILE | wc -l`
    failed=`grep "\*\*\*.*FAILED:" $LOGFILE | wc -l`
    aborted=`grep "\*\*\*.*ABORTED:" $LOGFILE | wc -l`

    ECHO ""
    LINE
    ECHO "=  Checking log file $LOGFILE for statistics:"
    ECHO "="
    ECHO "=  Total number of tests PASSED  : $passed"
    ECHO "=  Total number of tests FAILED  : $failed"
    ECHO "=  Total number of tests ABORTED : $aborted"
    LINE
    ECHO ""

    if (expr $failed + $aborted \> 0 > /dev/null)
    then
       ECHO "*** Not all tests completed successfully"
       ECHO "*** Check the file $LOGFILE for more information"
       cp $LOGFILE tpcw_eb.bad
       #
       # UP LINE FOR TEST SUITE
       # 
    fi
}


RUN()
{
    echo "$*"         >> $LOGFILE

    STATUS=1
        if test $SILENT -eq 1
        then
            eval $*             >> $LOGFILE 2>>/dev/null
        else
            eval $*             >> $LOGFILE
        fi
    STATUS=$?
}

START_SERVER1()
{
      LD_LIBRARY_PATH=`pwd`/lib:$LD_LIBRARY_PATH
      ddate=`date`
      starth=`date | cut -f 2 -d :`
      starts=`date | cut -f 3 -d :|cut -f 1 -d " "`
      rm -f *.lck
      $SERVER -c tpcw_eb.ini $*
      stat="true"
      while true 
	do
	  sleep 4
	      stat=`netstat -an | grep "[\.\:]$PORT1 " | grep LISTEN` 
	      if [ "z$stat" != "z" ] 
		then 
		    sleep 7 
		    LOG "PASSED: Virtuoso-Client successfully started on port $PORT1"
		    return 0
	      fi
        done
}

if [ z$1 = zload ]
then
    RUN $ISQL $PORT1 dba dba '"EXEC=shutdown"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    START_SERVER1
    RUN $ISQL $PORT1 dba dba '"EXEC=load tpcw_eb.sql"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    RUN $ISQL $PORT1 dba dba '"EXEC=load SET_URL.sql"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
else
    rm -f $LOGFILE
    LOG "PASSED: Started TPC-W Client $2"
    RUN $ISQL $PORT1 dba dba '"EXEC=load RUN.isql"' VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    LOG "PASSED: Finished TPC-W Client $2"
fi
