#!/bin/bash

# $Id: pgsql83_GENERIC.sh,v 1.3 2007/12/18 17:46:42 cbbrowne Exp $
# 
# For documentation, refer to doc library:
# http://somme:9080/Liberty/Index/Systems/DBA/index_html
# And click on the "New Database init Script"

CLUSTER='PGHEAD'
PG_VERSION='postgresql-HEAD'
PGPORT='7099'
PGHOST=localhost
PGUSER=postgres
ISHACMP='no'

BASE="/var/lib/postgresql/dbs"
DB_BASE="/var/lib/postgresql/dbs"

# Set these, or watch things break ;-)
CHECKPOINT_BASE=300         # default checkpoint timeout in seconds
CHECKPOINT_SPLAY=31         # checkpoint timeout maximum splay time

# These are all optional values
TIMEZONE=GMT                          # default for timezone
MAX_CONNECTIONS=100                   # default for max_connections
LISTEN_ADDRESSES="*"                  # default for listen_addresses
#SHARED_BUFFERS=48MB                  # default for shared_buffers
#WORK_MEM=2GB                         # default for work_mem
#BGWRITER_DELAY=200ms                 # default for bgwriter_delay
#BGWRITER_LRU_MAXPAGES=100            # default for bgwriter_lru_maxpages
#BGWRITER_LRU_MULTIPLER=2.0           # default for bgwriter_lru_multiplier
#WAL_BUFFERS=32MB                     # default for wal_buffers
CHECKPOINT_SEGMENTS=1                # default for checkpoint_segments
#RANDOM_PAGE_COST=2.5                 # default for random_page_cost
#EFFECTIVE_CACHE_SIZE=128MB           # default for effective_cache_size
LOG_MIN_DURATION_STATEMENT=1000      # default for log_min_duration_statement
LOG_DESTINATION=syslog
#LOGGING_COLLECTOR=on
#LOG_DIRECTORY=pg_log
#LOG_FILENAME="postgresql-%Y-%m-%d_%H%M%S.log"
#LOG_LINE_PREFIX="<%t/%p>"

POSTMASTER_USER='postgres'

# shouldn't have to edit any data below this for new clusters /
# installs

CHECKABLE_ITEMS="CHECKPOINT_SEGMENTS CHECKPOINT_TIMEOUT TIMEZONE
MAX_CONNECTIONS SHARED_BUFFERS WORK_MEM BGWRITER_DELAY
BGWRITER_LRU_MULTIPLER BGWRITER_LRU_MAXPAGES WAL_BUFFERS
CHECKPOINT_SEGMENTS RANDOM_PAGE_COST EFFECTIVE_CACHE_SIZE
LOG_MIN_DURATION_STATEMENT LOGGING_COLLECTOR PORT"

QUOTED_ITEMS="LISTEN_ADDRESSES LOG_DESTINATION LOG_DIRECTORY
LOG_FILENAME LOG_LINE_PREFIX"

# Typically this script should be only used by the postgres user.
# There are legitimate uses for other users (env and logtail).

PERL_BIN='/usr/bin/perl'

OLD_LOG_FILES_KEPT=100

# derive name / install from script name
#CLUSTER=`/bin/echo $0 | $PERLBIN -F'_' -lape '$_ = $F[0]; s|^.*/(.+)$|$1|o'`
#INSTALL=`/bin/echo $0 | $PERLBIN -F'_' -lape '$_ = $F[1]; substr($_, -3, 3, "")'`


echo "base: $BASE"
echo "dbbase: $DB_BASE"

PG_BASE_PATH="$DB_BASE/$PG_VERSION"
PG_BIN_PATH="$PG_BASE_PATH/bin"
PG_LIB_PATH="$PG_BASE_PATH/lib"
PG_MAN_PATH="$PG_BASE_PATH/man"

export PGBINDIR=$PG_BIN_PATH
LOG_PREFIX="$BASE/log"
PG_LOG_PATH="$LOG_PREFIX/$CLUSTER"
PGDATA="$BASE/$CLUSTER/$PG_VERSION"
PGCONF=${PGDATA}/postgresql.conf
PG_LOG_FILE="$PG_LOG_PATH/pg.log"
LD_LIBRARY_PATH="$PG_LIB_PATH:$LD_LIBRARY_PATH"
if [ -e "$PGCONF" ]; then
        CONFIG_PGPORT=`$PERL_BIN -lne 'print $1 if /^port\s*=\s*(\d+)\s*$/o' $PGCONF`
        echo "Expected port: $PGPORT  Configured port in $PGCONF $CONFIG_PGPORT"
	if [ "$CONFIG_PGPORT" -ne "$PGPORT" ]; then
		echo "PGPORT variable in init ($PGPORT) does not match port in $PGCONF ($CONFIG_PGPORT)"
		echo "Quitting."
		exit 99
	fi
fi
PGTZ='UTC'

ORIG_PATH="$PATH"
PATH="$PG_BIN_PATH:/usr/bin:/bin"

export PATH PGTZ PGPORT PGDATA LD_LIBRARY_PATH PG_LOG_PATH PG_BIN_PATH PG_LIB_PATH PG_MAN_PATH

test -x "$PG_BIN_PATH/postmaster" || (echo "missing postmaster"; exit 1)
test -x "$PG_BIN_PATH/pg_ctl" || (echo "missing pg_ctl"; exit 1)

case "$1" in
  start)
        if [ `whoami` != "$POSTMASTER_USER" ]; then 
	        echo "Not currently running as postgres user $POSTMASTER_USER. Quitting."
		exit 99
	fi
        echo "Starting PostgreSQL postmaster"
        ulimit -n 1024
	"$PG_BIN_PATH/pg_ctl" start 
        ;;
  autovacuum)
        if [ `whoami` != "$POSTMASTER_USER" ]; then 
	        echo "Not currently running as postgres user $POSTMASTER_USER. Quitting."
		exit 99
	fi
	echo "Starting Autovacuum Daemon"
	ulimit -n 1024
	#$PGBINPATH/pg_autovacuum -H localhost -p $PGPORT -U postgres -L $PGLOGPATH/pg_autovacuum.log -D -d 1 -s 1500 -S 2 -v 1000 -V 2 -a 1000 -A 500
	#$PGBINPATH/pg_autovacuum -H localhost -p $PGPORT -U postgres -L $PGLOGPATH/pg_autovacuum.log -D -d 1 -s 800 -S 5 -v 10000 -V 2
	"$PG_BIN_PATH/pg_autovacuum" -H localhost -p $PGPORT -U postgres -d 1 -s 800 -S 5 -a 1000 -A 500 -v 10000 -V 2 < /dev/null 2>&1 | \
                "$APACHE_BIN_PATH/rotatelogs" "$PG_LOG_PATH/pg_autovacuum/pg_autovacuum_%Y-%m-%d_%H:%M:%S.log" 10M &
	;;
  reload)
        if [ `whoami` != "$POSTMASTER_USER" ]; then 
	        echo "Not currently running as postgres user $POSTMASTER_USER. Quitting."
		exit 99
	fi
	echo "Reloading config files"
	"$PG_BIN_PATH/pg_ctl" reload 
	;;
  stop)
        if [ `whoami` != "$POSTMASTER_USER" ]; then 
	        echo "Not currently running as postgres user $POSTMASTER_USER. Quitting."
		exit 99
	fi
        echo "Stopping PostgreSQL postmaster"
        "$PG_BIN_PATH/pg_ctl" -m f stop
        ;;
  env)
	echo "Configuring env vars"
	PATH="$PG_BIN_PATH:$ORIG_PATH"
	MAN_PATH="$PG_MAN_PATH:$MAN_PATH"
	export PATH MAN_PATH PGHOST PGUSER
	;;
  logtail)
	echo "Tailing log file"
	(cd "$PG_LOG_PATH/$PG_CLUSTER"; tail -f `ls -1 pg_*.log | tail -1`)
	;;
  purgelogs)
	for DIR in "$PG_LOG_PATH/$PG_VERSION" "$PG_LOG_PATH/pg_autovacuum" ; do
		echo "Purging old log files in $DIR"
		pushd "$DIR"
		LOG_COUNT=`ls -1 pg_*.log | wc -l`
		DELETE_COUNT=$(( $LOG_COUNT - $OLD_LOG_FILES_KEPT ))
		if [ $DELETE_COUNT -gt 0 ]; then
			ls -1 pg_*.log | head -$DELETE_COUNT | xargs rm -f -- {}
		fi
		popd
	done
	;;
  mkdir)
        if [ `whoami` != "$POSTMASTER_USER" ]; then 
	        echo "Not currently running as postgres user $POSTMASTER_USER. Quitting."
		exit 99
	fi
        echo "Making dirs..."
        # logging stuff first

        for path in $PG_LOG_PATH "$PG_LOG_PATH/$PG_VERSION" "$BASE/$CLUSTER" "$BASE/$CLUSTER/$PG_VERSION" ; do
	if [ ! -d $path ]; then
	    echo "mkdir $path"
	    if mkdir -p $path; then
		echo "... created"
	    else
		echo "... failed"
	    fi
	else
	    echo "$path already present"
	fi
        done
        ;;

  initdb)
        if [ `whoami` != "$POSTMASTER_USER" ]; then 
	        echo "Not currently running as postgres user $POSTMASTER_USER. Quitting."
		exit 99
	fi
        if [ -e "${PGCONF}" ]; then
                echo "${PGCONF} already exists, skipping initdb"
        else
                INITDB_CMD="\"$PG_BIN_PATH/initdb\" --pgdata \"$PGDATA\" --encoding=SQL_ASCII --locale=C"
                echo "command: $INITDB_CMD"
                echo "-- 5 seconds to abort with CTRL-C"
                sleep 1; echo "-- 4"
                sleep 1; echo "-- 3"
                sleep 1; echo "-- 2"
                sleep 1; echo "-- 1"
                sleep 1; echo "-- starting initdb..."
		let "CHECKPOINT_TIMEOUT=${CHECKPOINT_BASE}+(${RANDOM}%${CHECKPOINT_SPLAY})s"
		PORT=$PGPORT
                if "$PG_BIN_PATH/initdb" --pgdata "$PGDATA" --encoding=SQL_ASCII --locale=C; then

		    SEDSCRIPT=${PG_BASE_PATH}/init-mods.sed
		    echo "" > ${SEDSCRIPT}
		    for parm in `echo ${CHECKABLE_ITEMS}`; do
			eval PARMVALUE=\$${parm}
			echo "Configuring parameter ${parm} - value=[${PARMVALUE}]"
			if [ "x$PARMVALUE" != "x" ]; then
			    lcparm=`echo $parm | tr "[:upper:]" "[:lower:]"`
			    echo "s/^#*${lcparm} = .*/${lcparm} = ${PARMVALUE}/" >> ${SEDSCRIPT}
			    grep "${lcparm} =" ${PGCONF}
			fi
		    done
		    for parm in `echo ${QUOTED_ITEMS}`; do
			eval PARMVALUE=\$${parm}
			echo "Configuring parameter ${parm} - value=[${PARMVALUE}]"
			if [ "x$PARMVALUE" != "x" ]; then
			    lcparm=`echo $parm | tr "[:upper:]" "[:lower:]"`
			    
			    echo "s/^#*${lcparm} = .*/${lcparm} = '${PARMVALUE}'/" >> ${SEDSCRIPT}
			    grep "${lcparm} =" ${PGCONF}
			fi
		    done
		    # now, rewrite postgresql.conf based on SEDSCRIPT
		    echo "Rewrite based on ${SEDSCRIPT}"
		    sed -i.bak -f ${SEDSCRIPT} ${PGCONF}

		    echo "You may require other configuration changes to ${PGCONF}"
		    echo "before you '$0 start'"
                else
		    echo "That didn't work."
                fi
        fi
        ;;
  *)
        echo "Usage: $0 [start|autovacuum|reload|stop|env|mkdir|initdb]"
        PATH=$ORIG_PATH
        export PATH
        ;;
esac
