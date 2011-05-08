#!/bin/sh
# $Id: check_3ware.sh 1286 2011-04-14 17:54:27Z beckerjes $
# (C) Jesse Becker

# Gotta be root to run tw_cli
if [ 0 != $UID ]; then
    exit 1;
fi

# Set a sane defaults.  Argument number 1 is 
# a path for the final report to be written.
# Argument 2 is the location for tw_cli (if not in /sbin)
REPORT_FILE="${1-/tmp/TW_report_file.txt}"
TW_CLI=${2-/sbin/tw_cli}


if [ ! -x "$TW_CLI" ]; then
    echo "+TW_missing_tw_cli"
    exit 1;
fi

# a list of temp files to remove at the end.
FILES=""

# Get a list of the controllers on this host.
CONTROLLERS=`$TW_CLI info | awk '/^c[0-9]+/{print $1}'`

# Loop over each controller
for C in $CONTROLLERS; do

	CINFO="/tmp/tw_con_info_$C"

	FILES="$FILES $CINFO"

    # Dump the controller info. From this, we can parse 
    # out the number of LUNs ("units") on the controller.
	$TW_CLI info $C > $CINFO

    # Extract the units from the controller info.
	UNITS=`awk '/^u[0-9]+/{print $1}' $CINFO`

    # Dump info from each unit.
	for U in $UNITS; do
		$TW_CLI info $C $U >> $CINFO
	done

done

# Add a datestamp, and concatenate all the files.
# this is so that a cfengine bundle can just read
# a single file, instead of 
date > $REPORT_FILE
cat $FILES >> $REPORT_FILE

# look for "bad stuff"
egrep -q 'NOT-PRESENT|INITIALIZING|INIT-PAUSED|REBUILDING|REBUILD-PAUSED|DEGRADED|MIGRATING|MIGRATE-PAUSED|RECOVERY|INOPERABLE|UNKNOWN' $REPORT_FILE

if [ 0 = "$?" ]; then
	# Found bad stuff!
	#echo "+TW_raid_okay"
	echo "+TW_raid_fault"
else
	# no bad stuff found
	echo "+TW_raid_okay"
	#echo "+TW_raid_fault"
fi

# Commented out...
#echo "=tw_report_file=$REPORT_FILE"

# Comment out, to see the temp files.
rm -f $FILES

exit 0

# EoL
