#!/bin/bash

# Todo lists nice and simple with a basic project planner capability
# by Kevin Groves kgroves@besbox.com

DEBUG=0

# use new sync method
# TODO make this optional
T_NEWSYNC=1

# TODO put as optional in sync config
# if T_SYNCALL is non-zero string then show all lines during sync else just show lines that are different (default)

# TODO now need a function to handle line and properties as its getting complicated :-)

function ulockfilerm {
rm ${TDFLOCK}
}

function ulockfile {
LOCKFILE=${TDFLOCK}
if [[ -a $LOCKFILE ]] ; then

        # check to see if the pid is running

        PID=`cat $LOCKFILE`
        kill -0 $PID >/dev/null 2>&1
        if [[ $? -ne 0 ]] ; then
                # it is done so clear lock
                rm -f $LOCKFILE
        else
                echo "Please try again"
                # now see if the process is stuck


                FILETIME=`stat -c %Y $LOCKFILE` 
                NOW=`date +%s`
                D=$(($NOW-$FILETIME)) 
                 if [ $D -gt 36000 ] ; then
                    # process has been running an hour. that is quite likely odd...
                	echo "Please try again"
                fi
        fi

        exit 99
fi

echo $$ >$LOCKFILE
}


function activity {
	# display an activity indicator (used for sync)

	if [[ -z "$pACTIVITY_INDc" ]] ; then
		pACTIVITY_INDc=0
	fi
		
	pACTIVITY_INDc=$((pACTIVITY_INDc+1))
	if [[ $pACTIVITY_INDc -eq 8 ]] ; then
		pACTIVITY_INDc=0
	fi

	if [[ $pACTIVITY_INDc -eq 0 ]] ; then
		pACTIVITY_IND="|"
	elif [[ $pACTIVITY_INDc -eq 1 ]] ; then
		pACTIVITY_IND="/"
	elif [[ $pACTIVITY_INDc -eq 2 ]] ; then
		pACTIVITY_IND="-"
	elif [[ $pACTIVITY_INDc -eq 3 ]] ; then
		pACTIVITY_IND="\\"
	elif [[ $pACTIVITY_INDc -eq 4 ]] ; then
		pACTIVITY_IND="|"
	elif [[ $pACTIVITY_INDc -eq 5 ]] ; then
		pACTIVITY_IND="/"
	elif [[ $pACTIVITY_INDc -eq 6 ]] ; then
		pACTIVITY_IND="-"
	elif [[ $pACTIVITY_INDc -eq 7 ]] ; then
		pACTIVITY_IND="\\"
	fi

	
	printf "\r%s" "$pACTIVITY_IND" 
}


# line format
#
# [_] <text> | <create date> | <user> | <tag> | <prio> | <category> | <mark completed> | <archived> | <note> | <highlight> | <due> | <est time> | <worked> | <percentage> | <trigger on complete> | <email> | <depends on id>


P_CREATEDATE=0
P_USER=1
P_TAG=2
P_PRIO=3
P_CATEGORY=4
P_MARKCOM=5
P_ARCHIVED=6
P_NOTE=7
P_HIGHLIGHT=8
P_DUE=9
P_ESTTIME=10
P_WORKED=11
P_PERCENT=12
P_TRIGGER=13
P_EMAIL=14
P_DEPENDID=15
P_WORKSTART=16
P_LISTID=17
P_SYNCID=18
P_SYNCLAST=19
P_SOURCEID=20
P_SEQ=21
P_REPEAT=22
P_NOTIFY=23
P_IMAGES=24
# repeat datum is from due date or completed date
P_RTYPE=25
# Task Type WF
P_TTYPE=26
# Max count of columns to check
P_MAXCOL=30

CAN_SYNC=1

T_SYNCINCLIST=""
T_SYNCEXCLIST=""


function defaultProps {
# function to scan PROPS array and fill in any missing strings with _

for el in $( seq 1 ${P_MAXCOL}) ; do
#	echo "Scan $el ${PROPS[$el]}"
	if [[ -z "${PROPS[$el]}" || "${PROPS[$el]}" = " _ " ]] ; then
#		echo "Filling with default"
		PROPS[$el]=" _ "
		if [[ $el -eq $P_SOURCEID ]] ; then
			PROPS[$el]=" t "
		fi
		if [[ $el -eq $P_LISTID ]] ; then
			PROPS[$el]=$T_SYNCCURLIST
		fi
		if [[ $el -eq $P_SEQ ]] ; then
			PROPS[$el]=" 100 "
		fi
		if [[ $el -eq $P_REPEAT ]] ; then
			PROPS[$el]=" 0 "
		fi
	fi
done
}





function cansync {
# Set THIS_LIST to check
# TODO Set THIS_SOURCE to check
# Returns 0 if not to sync, 1 is can sync

CAN_SYNC=0
CAN_SYNCL=0
CAN_SYNCS=0

#echo "Checking against /$THIS_LIST/"
#echo "Checking against /$THIS_SOURCE/"

if [[ -z "${T_SYNCINCLIST}" ]] ; then
	CAN_SYNC=1
#if [[ $DEBUG -eq 1 ]] ; then
#	echo "Inc all" >>/tmp/t.debug
#fi
else
# Include lists for sync here
for csl in $T_SYNCINCLIST ; do
#if [[ $DEBUG -eq 1 ]] ; then
#	echo "inc $csl " >>/tmp/t.debug
#fi
	if [[ " $csl " = "${THIS_LIST}"  || "$csl" = "${THIS_LIST}" ]] ; then
		CAN_SYNC=1
#if [[ $DEBUG -eq 1 ]] ; then
#		echo "*" >>/tmp/t.debug
#fi
	fi
done
fi

# Exclude lists for sync here
for csl in $T_SYNCEXCLIST ; do 
#if [[ $DEBUG -eq 1 ]] ; then
#	echo "exc $csl " >>/tmp/t.debug
#fi
	if [[ " $csl " = "${THIS_LIST}" || "$csl" = "${THIS_LIST}" ]] ; then
		CAN_SYNC=0
#if [[ $DEBUG -eq 1 ]] ; then
#		echo "*" >>/tmp/t.debug
#fi
	fi
done


# Exclude source for sync here
for csl in $T_SYNCEXCSOURCE ; do 
	if [[ " $csl " = "$THIS_SOURCE" || "$csl" = "${THIS_SOURCE}" ]] ; then
		CAN_SYNC=0
	fi
done

# Include source for sync here

for csl in $T_SYNCINCSOURCE ; do 
	if [[ " $csl " = "$THIS_SOURCE" || "$csl" = "$THIS_SOURCE" ]] ; then
		CAN_SYNC=1
	fi
done

if [[ -n "$T_SYNCEXECSOURCE" ]] ; then
	if [[ -n "${T_SYNCINCLIST}" ]] ; then
	# Allow for an exclusion on source but include individual lists if in there
		for csl in $T_SYNCINCLIST ; do
		#	echo "inc $csl "
			if [[ " $csl " = "${THIS_LIST}"  || "$csl" = "${THIS_LIST}" ]] ; then
				CAN_SYNC=1
		#		echo "*"
			fi
		done
	fi
fi
#if [[ $CAN_SYNCL -eq 0 ]] ; then
#	CAN_SYNC=0
#fi

#if [[ $CAN_SYNCS -eq 0 ]] ; then
#	CAN_SYNC=0
#fi

}

function syncupload {
			if [[ "${PROPS[$P_LISTID]}" = "  " ]] ; then
				PROPS[$P_LISTID]="default"
			fi
			if [[ "${PROPS[$P_SOURCEID]}" = "  " ]] ; then
				PROPS[$P_SOURCEID]="t"
			fi
			if [[ "${PROPS[$P_SEQ]}" = "  " ]] ; then
				PROPS[$P_SEQ]=${SEQ}
			fi
			if [[ -z "${PROPS[$P_SEQ]}" ]] ; then
				PROPS[$P_SEQ]=${SEQ}
			fi
			if [[ ${LINE:1:1} == "D" ]] ; then
				PROGRESS="--- ${PROGRESS}"
				# dont upload if not seen outside of this client and it has been softdeleted. other clients wont need to know!
				return
			fi

if [[ $DEBUG -eq 1 ]] ; then
			echo "---------------------- NEW" >>/tmp/t.debug
			echo "    * Uploading new /${PROPS[$P_SEQ]}/ $l" >>/tmp/t.debug
fi
				PROGRESS="--> ${PROGRESS}"
			curl   -H "Authorization: Token ${T_SYNCAPI}" -F "last_sync=${PROPS[$SYNCLAST]}" -F "line_no=${PROPS[$P_SEQ]}" -F "list_source=t" -F "list_id=${PROPS[$P_LISTID]}" -F "task_text=$l" -X POST $T_SYNCSERVER/api/v1/  >${TDF}.json 2>/dev/null

# TODO handle server error returning "<h1>Server Error (500)</h1>"
#sleep 2
#cp -v ${TDF}.json $(date +%s%).json

			# get id to update the line with
			PROPS[$P_SYNCID]=$(jq .id <${TDF}.json)
			PROPS[$P_SYNCLAST]=$(date +%s)
			echo "${PROPS[$P_SYNCID]}" >>${TDF}.seen

if [[ $DEBUG -eq 1 ]] ; then
echo "Id to update ${PROPS[$P_SYNCID]}" >>/tmp/t.debug
fi

# write out line for all items include those not in sync (for some reason)
			l=$(echo "${LINE}" | sed 's/ *$//')

			for el in "${PROPS[@]}" ; do 
				el=$(echo "$el" |sed 's/^ *//;s/ *$//')
				l="$l | $el"
			done
if [[ $DEBUG -eq 1 ]] ; then
echo "$l" >>/tmp/t.debug
fi
			curl   -H "Authorization: Token ${T_SYNCAPI}" -F "last_sync=${PROPS[$P_SYNCLAST]}" -F "line_no=${PROPS[$P_SEQ]}" -F "list_source=t" -F "list_id=${PROPS[$P_LISTID]}" -F "task_text=$l" -X PUT $T_SYNCSERVER/api/v1/${PROPS[$P_SYNCID]}/  >${TDF}.json 2>/dev/null
}

function sync {

# TODO detect for [D] on remote line to flag as a local delete
# TODO dont add any that have [D]
# TODO upload any that have [D] and delete locally

	# pass each line to the remote sync server api
type jq
if [[ $? -eq 1 ]]; then
	echo "We need jq for json parsing...."
	exit 1
fi

if [[ -z "$T_SYNCSERVER" ]] ; then
	echo "No sync server is setup"
	exit 1;
fi

if [[ -z "$T_SYNCAPI" ]] ; then
	echo "No sync server API Key is setup"
	exit 1;
fi

if [[ $SYNC -eq 2 ]] ; then
	# user has chosen to purge all soft deleted items 
	
	cat <<EOF
********************************************************************
* You have chosen to purge all 'D' marked items.
* 
* This is generally a safe thing to do and will speed up many opperations.
* These marked items will be pushed to sync server so that other clients
* will pick up the marking, and remove them from here. 
*
* Are you sure you want to do this? (YES to confirm. Anything else will abort)
EOF
read RES
if [[ "$RES" != "YES" ]] ; then
	exit 1;
fi
fi


if [[ $SYNC -eq 1 ]] ; then
	echo "|------ Sync In Progress ------|"
else
	echo "|------ Sync In Progress (With Purge) ------|"
fi

# lets make a backup just in case it really goes wrong and trashes the file! :-(

echo "Making local backup of ${TDF}"
cp --backup=t "${TDF}" "${TDF}.presync" -v


if [[ -n "$T_NEWSYNC" ]]; then
	# get the full list of items
	echo "Download task list..."

    # Init the full list for the rest of the processing

    echo "[">${TDF}.full

    # get first batch which may or may not have page count

    MOREPAGES=1
    MORE=""
    
    while [[ $MOREPAGES -gt 0 ]] ; do
        curl   -H "Authorization: Token ${T_SYNCAPI}"  -X GET $T_SYNCSERVER/api/v1/$MORE 2>/dev/null >${TDF}.page


        if [[ ! -s ${TDF}.page ]] ; then
            echo "Server has no data. Were you expecting this? Ctrl-C if not or press enter if OK"
            read A
            sleep 30
            echo "Starting sync...."
        fi
        #grep nginx ${TDF}.page >/dev/null
        #if [[ $? -eq 0 ]] ; then
        #    echo "Server has responded with an error. Were you expecting this? Ctrl-C if not or press enter if OK"
        #    read A
        #    sleep 30
        #fi

        if [[ $MOREPAGES -gt 1 ]] ; then
            echo "," >>${TDF}.full
        else
            TASKCT=$(jq -c '.count' ${TDF}.page)
            echo "Task Count: $TASKCT"
        fi

        # add this batch to the full batch 

        jq -c ".results" ${TDF}.page | cut -b2- | sed 's/\]$//' >>${TDF}.full 

        # Any more pages to get?
        MORE=$(jq -c '.next' ${TDF}.page|sed 's/null//'|sed 's/"//g'|cut -f2 -d'?')
        if [[ -z "$MORE" ]]; then
                MOREPAGES=0
        else
        
                MOREPAGES=$((MOREPAGES+1))
                MORE="?${MORE}"
        fi

        activity
    done
            echo "]" >>${TDF}.full
fi
echo
echo "Scanning tasks..."

if [[ $DEBUG -eq 1 ]] ; then
echo "-------------------------------------" >>/tmp/t.debug
echo "Starting" >>/tmp/t.debug
date >>/tmp/t.debug
fi
# record time we started sync (for flagging if a line changes)

grep T_SYNCLAST "${TDFS}" >/dev/null 2>&1
if [[ $? -eq 0 ]] ; then
	sed -i "s/^T_SYNCLAST=.*/T_SYNCLAST=${NOW}/" "$TDFS"
else
	echo "T_SYNCLAST=${NOW}" >>"$TDFS"
fi

SYNC_UP=0
SYNC_DOWN=0
SYNC_UN=0


echo >${TDF}.wi
echo >${TDF}.seen
cat "$TDF" | ( SEQ=100; C=1; 
	while read l ; do
		activity
		# get all the properties

		P_ARRAY=${l#*|}

		IFS='|' read -r -a PROPS <<< "$P_ARRAY"
		defaultProps 

		LINE=${l%%|*}

		SID=$(echo "${PROPS[$P_SYNCID]}" | sed 's/ //g')
if [[ $DEBUG -eq 1 ]] ; then
echo "SID 1 ${SID}" >>/tmp/t.debug
fi
		if [[ "$SID" = "_" ]] ; then
			SID=$(date +%s)
		fi
if [[ $DEBUG -eq 1 ]] ; then
echo "SID 2 ${SID}" >>/tmp/t.debug
fi
			if [[ "${PROPS[$P_SEQ]}" = "  " ]] ; then
				PROPS[$P_SEQ]=${SEQ}
			fi
			if [[ -z "${PROPS[$P_SEQ]}" ]] ; then
				PROPS[$P_SEQ]=${SEQ}
			fi
#echo "seq /${PROPS[$P_SEQ]}/"
		# build start of progess line


		PROGRESS=": ${LINE}"

if [[ $DEBUG -eq 1 ]] ; then
echo "---" >>/tmp/t.debug
echo "Line ${LINE}" >>/tmp/t.debug
fi

		# look up sync id for task
		# if not exists then add with current sync time and update sync id to the one it gives back
		# if exists then see if there is a sync time diff
		#    if this is newer then update the line and sync time
		#    if this is older then replace with pulled item

		# TODO check for new items added by another sync
		# TODO deal with deletion (use 'D' to mark as deleted and not show until sync has purged them)

		# add to the list of sync ids we are processing so we can then later find out if any new ones should be pulled down


# CHeck to see if we are interested in doing this one

# Set THIS_LIST to check
# Set THIS_SOURCE to check
THIS_LIST="${PROPS[$P_LISTID]}"
THIS_SOURCE="${PROPS[$P_SOURCEID]}"
		cansync

		echo "${SID}" >>${TDF}.seen

if [[ $CAN_SYNC -eq 0 ]] ; then
	PROGRESS="### ${PROGRESS}"
	echo "$l" >>${TDF}.w 
else

if [[ $DEBUG -eq 1 ]] ; then
	echo "Checking task  /${l}/" >>/tmp/t.debug
fi

if [[ -n "$T_NEWSYNC" ]]; then
if [[ $DEBUG -eq 1 ]] ; then
	echo "Get task from download /${SID}/" >>/tmp/t.debug
fi
	# look up id in fullv2 and create RES var
        if [[ -z "${SID}" ]] ; then
             SID=0
        fi

	RES=$(jq -c ".[] | select(.id == ${SID})" ${TDF}.full 2>/dev/null)
	#echo $RES
if [[ $DEBUG -eq 1 ]] ; then
	echo "Download lookup result /${RES}/" >>/tmp/t.debug
fi
else
if [[ $DEBUG -eq 1 ]] ; then
echo "Lookup task by id ${SID}" >>/tmp/t.debug
fi
		# look up task by id
		RES=$(curl   -H "Authorization: Token ${T_SYNCAPI}"  -X GET $T_SYNCSERVER/api/v1/${SID}/ 2>/dev/null) 
fi
if [[ $DEBUG -eq 1 ]] ; then
echo "*${RES}*" >>/tmp/t.debug
fi

		# check for look up failure
		FAILL=0


		if [[ "$RES" = "{\"detail\":\"Not found.\"}" ]] ; then
			FAILL=1
if [[ $DEBUG -eq 1 ]] ; then
echo "Faill a" >>/tmp/t.debug
fi
		fi
		if [[ -z "$RES" ]] ; then
			FAILL=1
if [[ $DEBUG -eq 1 ]] ; then
echo "Faill b" >>/tmp/t.debug
fi
		fi
		if [[ $SID -eq 0 ]] ; then
			FAILL=1
if [[ $DEBUG -eq 1 ]] ; then
echo "Faill c" >>/tmp/t.debug
fi
		fi

if [[ $DEBUG -eq 1 ]] ; then
echo "Faill ${FAILL}" >>/tmp/t.debug
fi

		if [[ $FAILL -eq 0 ]] ; then
# its here
if [[ $DEBUG -eq 1 ]] ; then
			echo "    * It existsi" >>/tmp/t.debug
fi
			echo "$RES">${TDF}.json

# get last sync time

			LASTSYNC=$(cat ${TDF}.json | jq .last_sync)

			if [[ ${PROPS[$P_SYNCLAST]} -lt $LASTSYNC ]] ; then

if [[ $DEBUG -eq 1 ]] ; then
				echo "    * Server has most recent, replacing" >>/tmp/t.debug
				cat ${TDF}.json >>/tmp/t.debug
fi
				PROGRESS="<== ${PROGRESS}"
				SYNC_DOWN=$((SYNC_DOWN+1))
				jq -r .task_text <${TDF}.json >>${TDF}.w
			else


if [[ $DEBUG -eq 1 ]] ; then
				echo "sync times: us ${PROPS[$P_SYNCLAST]} server  $LASTSYNC " >>/tmp/t.debug
fi
				if [[ ${PROPS[$P_SYNCLAST]} -gt $LASTSYNC ]] ; then
if [[ $DEBUG -eq 1 ]] ; then
					echo "    * We have most recent, uploading $l" >>/tmp/t.debug
fi
					PROGRESS="==> ${PROGRESS}"
					SYNC_UP=$((SYNC_UP+1))

					curl   -H "Authorization: Token ${T_SYNCAPI}" -F "last_sync=${PROPS[$P_SYNCLAST]}" -F "line_no=${PROPS[$P_SEQ]}" -F "list_source=t" -F "list_id=${PROPS[$P_LISTID]}" -F "task_text=$l" -X PUT $T_SYNCSERVER/api/v1/${SID}/  >${TDF}.json 2>/dev/null

										echo "$l" >>${TDF}.w 
				fi
			fi

				if [[ ${PROPS[$P_SYNCLAST]} -eq $LASTSYNC ]]; then
if [[ $DEBUG -eq 1 ]] ; then
					echo "    * No change" >>/tmp/t.debug
fi

					if [[ $SYNC -eq 2 ]] ; then				
						if [[ ${LINE:1:1} == "D" ]] ; then
						
							# now archived on completion
                                                        # echo "$l" >>${TDFA} 
							PROGRESS="--- ${PROGRESS}"
							SYNC_UN=$((SYNC_UN+1))
							# TODO Mark as archived on server
						else
							PROGRESS="<=> ${PROGRESS}"
							SYNC_UN=$((SYNC_UN+1))
							echo "$l" >>${TDF}.w 
						fi
					else

						PROGRESS="<=> ${PROGRESS}"
							SYNC_UN=$((SYNC_UN+1))
						echo "$l" >>${TDF}.w 
					fi
				fi

		else 


if [[ $DEBUG -eq 1 ]] ; then
echo "syncupload call $l" >>/tmp/t.debug
fi
			syncupload
			SYNC_UP=$((SYNC_UP+1))

			if [[ $SYNC -eq 2 ]] ; then
				if [[ ${l:1:1} != "D" ]] ; then
				   echo "$l" >>${TDF}.w 
				fi
			else
			   echo "$l" >>${TDF}.w 
			fi
		fi
fi

		if [[ ${PROGRESS:0:3} == "<=>" ]] ; then
			if [[ -n "$T_SYNCALL" ]] ; then
				printf "\r${PROGRESS}\n"
			fi
		else
			printf "\r${PROGRESS}\n"
		fi
	C=$((C+1))
	SEQ=$((SEQ+100))
	done

echo
echo "Uploaded: ${SYNC_UP} Downloaded: ${SYNC_DOWN} Unchanged: ${SYNC_UN}"

 )  


# process new lines from server

# get the full list of items


if [[ -z "$T_NEWSYNC" ]]; then
	curl   -H "Authorization: Token ${T_SYNCAPI}"  -X GET $T_SYNCSERVER/api/v1/ 2>/dev/null >${TDF}.full
fi

# get the ids from the json of the full list and add any that are unknown

jq -r ".[] | .id" ${TDF}.full | sort >${TDF}.full.id

#IFS=' ' read -r -a Array1 <<< "$(cat ${TDF}.full.id | sed 's/\n/ /g')"
#IFS=' ' read -r -a Array2 <<< "$(cat ${TDF}.seen | sed 's/\n/ /g')"

readarray Array1 <${TDF}.full.id
readarray Array2 <${TDF}.seen


Array3=()
for i in "${Array1[@]}"; do
     skip=
     for j in "${Array2[@]}"; do
         [[ $i == $j ]] && { skip=1; break; }
     done
     [[ -n $skip ]] || Array3+=("$i")
done
#declare -p Array3

#echo "full"
#cat ${TDF}.full.id
#echo "seen"
#cat ${TDF}.seen

echo
echo "Looking for new items from other lists: "

SYNC_DOWN=0
for a in ${Array3[@]} ; do
#	echo "* Getting new task ID $a"


#	jq ".[${a}].task_text" <${TDF}.full

if [[ -n "$T_NEWSYNC" ]]; then
#	echo "Get task from download ${SID}"
	# look up id in fullv2 and create RES var
	jq -c ".[] | select(.id == ${a})" ${TDF}.full >${TDF}.item 2>/dev/null
else
	curl   -H "Authorization: Token ${T_SYNCAPI}"  -X GET $T_SYNCSERVER/api/v1/${a}/ 2>/dev/null >${TDF}.item
fi

	# extract text
	
	NEWLINE=$(jq -r ".task_text"<${TDF}.item)

THIS_LIST="$(jq -r ".list_id"<${TDF}.item)"
THIS_SOURCE="$(jq -r ".list_source"<${TDF}.item)"
		cansync

if [[ $CAN_SYNC -eq 0 ]] ; then
#		printf "#";
	activity
else
	if [[ ${NEWLINE:1:1} == "D" ]] ; then
#		echo "   ...Ignoring deleted line we don't have"
	activity
	#	printf "D";
		# TODO Mark as archived on server if doing purge
	else

		# now make sure the id on the json is the id in the line to keep things in sync

		P_ARRAY=${NEWLINE#*|}
		IFS='|' read -r -a PROPS <<< "$P_ARRAY"
		defaultProps 

		TLINE=${NEWLINE%%|*}
		
        echo "${TLINE}"
		PROPS[$P_SYNCID]=$a
		for el in "${PROPS[@]}" ; do 
			el=$(echo "$el" |sed 's/^ *//;s/ *$//')
			TLINE="${TLINE} | $el"
		done


		#printf "+";

	activity
		SYNC_DOWN=$((SYNC_DOWN+1))
		echo "$TLINE" >>${TDF}.w
if [[ $DEBUG -eq 1 ]] ; then
echo "New line ${TLINE}" >>/tmp/t.debug
fi
	fi
fi	
done
echo
echo "New tasks added: ${SYNC_DOWN}"


#rm -f ${TDiF}.full.id ${TDF}.seen ${TDF}.item ${TDF}.full ${TDF}.json

mv ${TDF}.w ${TDF}
echo
echo "|------ Sync Done ------|"

}




# TODO display the line in the global LINE var
# format and output the LINE contents from the definations for the user

function displayLine {
	# pass the line number 
#	if [[ $SHOWPROPS -eq 0 ]] ;then
#		LINE=${LINE/|*/}; 
#	fi


if [[ $COLLAPSE_TREE -ge 1 ]] ; then
	# hide children


	TOFF=$((1+(COLLAPSE_TREE * 3)))
	if [[ ${LINE:$TOFF:1} == "-" ]] ; then
		return
	fi
fi


# if soft deleted (for task sync) then hide line

	if [[ ${LINE:1:1} == "D" ]] ; then
		return
	fi

# line is for display

highon=$dimon		
highoff=$dimoff

			if [[ ${LINE:1:1} == " " ]] ; then
				highon=""
                                highoff=""
			fi


			# get all the properties

			P_ARRAY=${LINE#*|}

			IFS='|' read -r -a PROPS <<< "$P_ARRAY"

			E=$P_MAXCOL ; 
			while [[ $E -ge 0 ]] ; do 
#				PROPS[$E]=$(echo "${PROPS[$E]}" |sed 's/^ *//;s/ *$//')
				if [[ "${PROPS[$E]}" == " _ " ]] ; then
					PROPS[$E]=""
				fi
				E=$((E-1));
			done

# apply sync list filters if one is set

if [[ -n "$T_SYNCCURLIST" ]] ; then
	# List has a filter...

#	echo  "* ${PROPS[$P_LISTID]:1} *"
#	echo "* $T_SYNCCURLIST *" 
	if [[ $GFILTER -eq 0 ]] ; then
		# And no global search filter is active
		if [[ "${PROPS[$P_LISTID]}" != " $T_SYNCCURLIST " ]] ; then
			return
		fi
	fi
	
fi
			# get the front of line

			LINE=${LINE%%|*}




	# highlight line

	if [[ -n "${PROPS[$P_HIGHLIGHT]}" ]] ; then
                # see if we are using single or double value
                IFS=":" read -r -a HP <<< "${PROPS[$P_HIGHLIGHT]}"
                HF=""
                HB=""
                if [[ -n "$HP[0]" ]] ; then
                    HF="tput setaf ${HP[0]};"
                fi
                if [[ -n "$HP[1]" ]] ; then
                    HB="tput setab ${HP[1]};"
                fi
		#highon=$(tput setaf ${PROPS[$P_HIGHLIGHT]})
		highon=$($HB $HF)
	fi

	L="${highon}$(printf %03d $1) "
	if [[ ${PROPS[$P_SYNCLAST]} -gt $T_SYNCLAST ]] ; then
	L="${L}>"
	else
	L="${L}:"
	fi

	L="$L $LINE" ; 


	# display properties
	for el in "${P_DISP[@]}" ; do
		i=""
		case "$el" in 
                    TAG) if [[ -n "${PROPS[$P_TAG]}" ]] ; then 
				i="${hl_tag}#${PROPS[$P_TAG]:1} ${hl_reset}" 
				fi
			;;
		    MARKCOM) # if there is a work started date then reformat for display

 			WS=${PROPS[$P_WORKSTART]}
			WS=${WS// /}
                        if [[ $WS -gt 0 ]] ; then
				WS="$(date -d @${WS}) - "
			 	if [[ ${PROPS[$P_MARKCOM]} -eq 0 ]] ; then
					WS="${hl_completed}${WS}${hl_highlight}IN PROGRESS"
					if [[ ${PROPS[$P_WORK]} -gt 0 ]] ; then
						# some work idone so show how much
						WS="${WS}[${PROPS[$P_WORKED]}/${PROPS[$P_ESTTIME]}]"
					fi
					WS="${WS}${hl_reset}"
				fi
			fi
			MC=""
			 if [[ ${PROPS[$P_MARKCOM]} -gt 0 ]] ; then

				MC="$( date --date="@${PROPS[$P_MARKCOM]}" )"
			fi

			 if [[ ${PROPS[$P_MARKCOM]} -gt 0 || -n $WS ]] ; then

				i="${hl_completed}(${WS}${MC})${hl_completed}"
				#i="${dimon}(${WS}$( date --date="@${PROPS[$P_MARKCOM]}" ))${dimoff}"
				fi
			;;
		    CATEGORY) i="${hl_cat}${PROPS[$P_CATEGORY]}${hl_reset}"
			;;
		    PRIO) if [[ -n "${PROPS[$P_PRIO]}" ]] ; then
				i="${hl_priority}(P${PROPS[$P_PRIO]})${reset}"
				fi
			;;
		    CREATEDATE) i=${PROPS[$P_CREATEDATE]}
			;;
		    USER) i=${PROPS[$P_USER]}
			;;
		    ARCHIVED) i=${PROPS[$P_ARCHIVED]}
			;;
		    DUE) if [[ -n "${PROPS[$P_DUE]}" ]] ; then
				if [[ "${PROPS[$P_DUE]}" -ne 0 ]]; then
				i=$(date --date="@${PROPS[$P_DUE]:1}")
			        overdue=""
				if [[ ${PROPS[$P_DUE]} -lt ${NOW} ]] ; then
					overdue=" ${hl_highlight}OVERDUE${reset}"	
				fi
				i="${hl_due}(Due: ${i}${overdue}"
                                if [[ ${PROPS[$P_REPEAT]} -gt 0 ]] ; then
					# there is a repeat so display a hint
					i="${i}[+${PROPS[$P_REPEAT]}"
					if [[ ${PROPS[$P_RTYPE]} = " 1 " ]]; then
						i="${i}c]"
					else
						i="${i}d]"
					fi

   				fi
                                i="${i})${hl_reset}"
				fi
			fi
			;;
		    ESTTIME) if [[ -n "${PROPS[$P_ESTTIME]}" ]] ; then
				i="| ${hl_gannt}Est: ${PROPS[$P_ESTTIME]}${hl_reset} "
				fi
			;;
		    WORKED) if [[ -n "${PROPS[$P_WORKED]}" ]] ; then
				i="| ${hl_gannt}Wrk: ${PROPS[$P_WORKED]}${hl_reset} "
				fi
			;;
		    PERCENT) if [[ -n "${PROPS[$P_PERCENT]}" ]] ; then
				i="| ${hl_gannt}${PROPS[$P_PERCENT]}%${hl_reset} "
			fi
			;;
		    EMAIL) i="${dimon}${PROPS[$P_EMAIL]}${dimoff}"
			;;
		    NOTE) if [[ -n ${PROPS[$P_NOTE]} ]] ; then
				# see if a multiline
				echo "${PROPS[$P_NOTE]}" | grep "~" >/dev/null 2>&1
				if [[ $? -eq 0 ]] ; then
					i="${dimon}${hl_note}$( echo "${PROPS[$P_NOTE]}" | sed 's/~/\n     /g')${dimoff}"
				else
					i="${dimon}${hl_note}:: ${PROPS[$P_NOTE]} ::${dimoff}"
				fi
			fi 
			;;
                    IND) i="${hl_ind}"
				if [[ -n ${PROPS[$P_LISTID]} ]] ; then
					if [[ "${PROPS[$P_LISTID]}" != " " ]] ; then 


if [[ "${PROPS[$P_LISTID]}" =~ "-" ]]; then
	# list id is a slug so show all of it
						i="${i}/${PROPS[$P_LISTID]}/"
else


						i="${i}/${PROPS[$P_LISTID]:1:3}/"
fi
					fi
				fi
				if [[ ${PROPS[$P_REPEAT]} -gt 0 ]] ; then
					i="${i}>"
				fi
				if [[ -n ${PROPS[$P_NOTE]} ]] ; then
					i="${i}+"
				fi
				if [[ ${PROPS[$P_ESTTIME]} -gt 0 ]] ; then
					i="${i}%"
				fi
				if [[ -n ${PROPS[$P_EMAIL]} ]] ; then
					i="${i}@"
				fi
				if [[ -n ${PROPS[$P_DUE]} ]] ; then
					if [[ ${PROPS[$P_DUE]} -ne 0 ]] ; then
					i="${i}!"
					if [[ ${PROPS[$P_DUE]} -lt ${NOW} ]] ; then
						i="${i}!"	
					fi
					fi
				fi
				i="${i}${hl_reset}"
			 
			;;
#P_NOTE=9
#P_HIGHLIGHT=10
#P_TRIGGER=15
#P_DEPENDID=17
		esac
		L="$L $i"
	done

	if [[ -n $FILTER ]] ; then
		# apply a filter check
		if [[ $L = *"$FILTER"* ]] ; then
			:
		else
			return
		fi
	fi
        # List if due is coming up
	if [[ ${UPCOMING} -gt 0 ]] ; then
		# apply a filter check
		if [[ ${PROPS[$P_DUE]} -gt $NOW ]]; then
			if [[ ${PROPS[$P_DUE]} -lt ${UPCOMING} ]] ; then
				:
			else
				return
			fi
		else
			return
		fi
	fi
        # List last changed
	if [[ ${LASTCHANGED} -gt 0 ]] ; then
		# apply a filter check
			if [[ ${PROPS[$P_SYNCLAST]} -gt ${LASTCHANGED} ]] ; then
				:
			else
				return
			fi
	fi

	echo "$L${highoff}${hl_reset}"

	if [[ $SHOWGANNT -eq 1 ]] ; then
		if [[ ${PROPS[$P_ESTTIME]} -gt 0 ]] ; then

			# TODO get indent level
			i="${L%+*}+  ||"
#			i="          |"
		
			# calc the est time bar length
			if [[ $GANNT_UP -eq 1 ]] ; then
				EB=$( awk -v i="${i}" -v e="${PROPS[$P_ESTTIME]}" -v st=$GANNT_STEP 'BEGIN {s=sprintf("%200s",""); gsub(/ /,"=",s);print i substr(s,0,(e*st)); }')
			else
				EB=$( awk -v i="${i}" -v e="${PROPS[$P_ESTTIME]}" -v st=$GANNT_STEP 'BEGIN {s=sprintf("%200s",""); gsub(/ /,"=",s);print i substr(s,0,(e/st)); }')
			fi
			echo "${hl_gannt}${EB} Est: ${PROPS[$P_ESTTIME]}${hl_reset}"

			# if there is a work started date then reformat for display

# 			WS=${PROPS[$P_WORKSTART]}
 #                       if [[ $WS -gt 0 ]] ; then
#				WS=${WS// /}
#				echo "-${WS}-"
#				WS="$(date -d @${WS})"
#			fi
#
 #			WE=${PROPS[$P_MARKCOM]}
  #                      if [[ $WE -gt 0 ]] ; then
#				WE=${WE// /}
#				echo "-${WS}-"
#				WS="${WS} - $(date -d @${WE})"
#			fi

			# calc the work time bar length
			if [[ $GANNT_UP -eq 1 ]] ; then
				EB=$( awk -v i="${i}" -v p="${PROPS[$P_PERCENT]}" -v e="${PROPS[$P_WORKED]}" -v st=$GANNT_STEP 'BEGIN {s=sprintf("%200s",""); gsub(/ /,"#",s);printf("%s%s %s %s%%",i,substr(s,0,(e*st)),e, p); }')
			else
				EB=$( awk -v i="${i}" -v p="${PROPS[$P_PERCENT]}" -v e="${PROPS[$P_WORKED]}" -v st=$GANNT_STEP 'BEGIN {s=sprintf("%200s",""); gsub(/ /,"#",s);printf("%s%s %s %s%%",i,substr(s,0,(e/st)),e, p); }')
			fi
			echo "${hl_gannt}${EB}${hl_reset}"

		fi
	fi


}

# new process sequence to do
#
# if display then display as required
# if no flags then new task so add it
# 
# get the line required
# process flags
# rebuild file with modified line




NOW=$(date +%s)


# params

OLDTASKS=0
OLDTONEW=0
UNMARK=0
DEPENDS=0
PRIO=-1
TAG=""
TOARCHIVE=1
SHOWPROPS=0
CATEGORY=""
NOTE=""
EMAIL=0
FILTER=""
GFLITER=0
HIGHLIGHT=""
DUEDATE=0
SORTON=""
MOVETO=0
SETLIST=0
SWITCHLIST=0
IGNORE_T_TODO=0
COLLAPSE_TREE=0
REINDENT=-1
EST=-1
WORK=-1
SHOWGANNT=0
# totals for gannt rendering
GANNT_EST=0
GANNT_WORK=0
SYNC=0
REPORT=0
ISREPEAT=-1
ISRTYPE=""
ISTTYPE=""
UPCOMING=-1
LASTCHANGED=-1

# indicate line specific or global (settings) flags were used

GIVEN_LINE_FLAG=0
GIVEN_GLOBAL_FLAG=0

while getopts ":Cud:p:t:aihc:nef:F:H:Ds:E:W:gm:I:oOlLzZrR:b:T:U:S:" opt; do
  case ${opt} in
    z ) # perform sync
        SYNC=1
        ;;
    Z ) # perform sync with purge
        SYNC=2
        ;;
    I ) # set new indent level for marked tasks
	REINDENT=$OPTARG
	GIVEN_LINE_FLAG=1
        ;;
    C ) # collapse or display project tree
	    COLLAPSE_TREE=$((COLLAPSE_TREE+1))
	    #echo $COLLAPSE_TREE
	GIVEN_LINE_FLAG=1
       ;;
    i ) # ignore T_TODO
        IGNORE_T_TODO=1
       ;;
    m ) # Move line to
        MOVETO=$OPTARG
	GIVEN_GLOBAL_FLAG=1
     ;;
    o ) # List from archive (old tasks)
        OLDTASKS=1
	GIVEN_GLOBAL_FLAG=1
     ;;
    g ) # render gannt lines
        SHOWGANNT=1
	GIVEN_LINE_FLAG=1
     ;;
    E ) # set estimate of work required
        EST=$OPTARG
	GIVEN_LINE_FLAG=1
     ;;
    W ) # record some work against the line
        WORK=$OPTARG
	GIVEN_LINE_FLAG=1
     ;;
    R ) # toggle as a repeating due date
        ISREPEAT=$OPTARG
	GIVEN_LINE_FLAG=1
     ;;
    b ) # toggle as a repeating due date based on due or completed
        ISRTYPE=$OPTARG
	GIVEN_LINE_FLAG=1
     ;;
    T ) # Assign Task Type WF 
        ISTTYPE=$OPTARG
	GIVEN_LINE_FLAG=1
     ;;
    r ) # display some reports
        REPORT=1
	GIVEN_GLOBAL_FLAG=1
     ;;
    U ) # display upcoming tasks
        UPCOMINGD=$OPTARG
        UPCOMING=$((UPCOMINGD * 86400))
        UPCOMING=$((UPCOMING + NOW))
        # calc unix timestamp to use
	echo "Non-overdue tasks coming up in the next $OPTARG days"

	GIVEN_GLOBAL_FLAG=1
       GFILTER=1
     ;;
    S ) # display last changed
        LASTCHANGEDD=$OPTARG
        LASTCHANGED=$((LASTCHANGEDD * 86400))
        LASTCHANGED=$((NOW - LASTCHANGED))
        # calc unix timestamp to use
	echo "Tasks changed within the last $OPTARG days"

	GIVEN_GLOBAL_FLAG=1
       GFILTER=1
     ;;
    s ) # temp sort by property
        SORTON=$OPTARG
	GIVEN_LINE_FLAG=1
     ;;
 
    O ) # Old to new
      OLDTONEW=1
	GIVEN_LINE_FLAG=1
      ;;
    u ) # unmark
      UNMARK=1
	GIVEN_LINE_FLAG=1
      ;;
    f ) # list filter
      FILTER=$OPTARG
	GIVEN_LINE_FLAG=1
      ;;
    F ) # global filter
      FILTER=$OPTARG
      GFILTER=1
	GIVEN_LINE_FLAG=1
      ;;
    D ) # add due date
      DUEDATE=1
	GIVEN_LINE_FLAG=1
      ;;
    H ) # add highlighting to line
      HIGHLIGHT=$OPTARG
	GIVEN_LINE_FLAG=1
      ;;
    e ) # add email trigger
      EMAIL=1
	GIVEN_LINE_FLAG=1
      ;;
    d ) # depends on item
      DEPENDS=$OPTARG
	#GIVEN_LINE_FLAG=1
      ;;
    l ) # set list on item
      SETLIST=1
	GIVEN_LINE_FLAG=1
      ;;
    L ) # switch list
      SWITCHLIST=1
	GIVEN_GLOBAL_FLAG=1
      ;;
    c ) # add a category
      CATEGORY=$OPTARG
	GIVEN_LINE_FLAG=1
      ;;
    n ) # add a note
      NOTE=1
	GIVEN_LINE_FLAG=1
      ;;
    t ) # a hash tag
      TAG=$OPTARG
	GIVEN_LINE_FLAG=1
      ;;
    a ) # if marking as done then move to archive (default)
      TOARCHIVE=1
GIVEN_GLOBAL_FLAG=1
      ;;
    A ) # if marking as done then dont move to archive
      TOARCHIVE=0
GIVEN_GLOBAL_FLAG=1
      ;;
#    P ) # show task properties
#      SHOWPROPS=$OPTARG
#      GIVEN_GLOBAL_FLAG=1
#      ;;
    p) # set prio on a line
	    PRIO=$OPTARG
	GIVEN_LINE_FLAG=1
	    ;;
    h) # display help
      cat <<EOF
Command line options:


To add a line:
--------------
	
t <text>


Line Updates:
-------------

t <options> 



<tid> [<tid> <tid>.. ] Will mark as done. If an email is set then send a email to that user

s                      Sort by item name (unless dependencies are present)
-a                     When marking as done send to archive (default enabled)
-A                     When marking as done disable send to archive
-b <type> <tid>        Can be 'd' or 'c' to base repeating on completed or due date (default)
-c <category> <tid..>  Add a category
-C                     Collapse nested tasks
-d <tid> <text>        When adding put as dependant on another task
-D <tid> <date>        Set a due date on the line using any format that 'date' can handle
-e <tid> <email>       Add an email address to an item. If you complete a task an email will be sent to that
                       address using the default sender, if you have T_SENDER set then this will be used instead.
-f <string>            Display todo list with a case sensitive filter (current list) 
-F <string>            Display todo list with a case sensitive filter (all lists)
-H <colour>[:<back>]   Set a colour foreground and background highlight on the line(s) (1-8)
-i                     Ignore T_TODO variable and use defaults
-I <level> <tid..>     Set new indent level for the given task(s)
-m <newtid> <tid>      Move <tid> to be at line <newtid>
-n <tid> <note>        Add a note to the item (if text starts with a plus then add another line)
-o                     List contents of archive (old completed) tasks
-O <tid>               Move <tid> from archive list to current. Use with -o.
-p <prio> <tid..>      Set priority mark on a task or list of tasks
-R <days> <tid>        Set a repeating due date to number of days after due after each completion (0=disable)
-s <flag>              Temp sort by the applied flag
-S <days>              List tasks changed within the last <days>
-t <tag> <tid..>       Set a tag to a task or list of tasks. Use -/+ infront to add or remove from tag list
-T <type> <tid>        Task type for special work flow (See mytdos.besbox.com)
-u <tid>               Unmark task or list of tasks
-U <days>              List upcoming due dates within the next <days>

Project Planning Switches:
--------------------------

-E <unit> <tid..>      Estimate of time to complete. Unit can mean anything, just be consistent
-W <unit> <tid..>      Record a unit of work against a task.
-g                     Display list with Gannt display


Task Sync Switches:
-------------------

-h                     Shows help and summary of lists present
-l <tid> [<list name>] Assign task to a list called <list name>. 
                       If <list name> is empty then uses current list
-l                     Display task list with a summary of list names at the end
-L <list name>         Switch task display to <list name>
-L                     Switch task display to all lists
-r                     Display a tabluar report against tasks TODO
-z                     Full sync of tasks
-Z                     Full sync of tasks (plus purge of soft deleted items)

NOTE: For sync to function you will need to set the T_SYNCAPI key in the
config file .todorc-sync




Configuation Files:
-------------------


* Display formatting - .todorc-display

Set the todo list's property display comma delited flags when listing items:

			CREATEDATE
			USER
			TAG
			PRIO
			CATEGORY
			MARKCOM
			ARCHIVED
			NOTE
			IND  	Show indicator for presence of notes (+), email (@), a % is shown for work tracking, has 
                                a due date (!), greater than (>) to show it is a repeating task and if overdue (!!)
			DUE
			ESTTIME
			WORKED
			PERCENT
			TRIGGER
			EMAIL

If enviromental var T_DISPLAY is set with above, this will over ride the default

Defaults to TAG,PRIO,MARKCOM,IND


T_TODO var can be given to specify a non-standard todo list.
EOF




#		ulockfilerm t
	exit 0
     ;;
    \? ) echo "For useage: t -h"
      ;;
  esac
done

shift $((OPTIND -1))


# locate todo.txt
# prefer local dir and if not found then try home 

TDF=~/todo.txt
TDFLOCK=~/todo.txt.lock
TDFA=~/todo-archive.txt
TDFC=~/.todorc-display
TDFH=~/.todorc-highlight
TDFS=~/.todorc-sync
TDFO=~/.todorc-opts

if [[ -a ./todo.txt ]] ; then
	TDF="./todo.txt"
	TDFLOCK="./todo.txt.lock"
	TDFA="./todo-archive.txt"
	TDFC="./.todorc-display"
	TDFH="./.todorc-highlight"
	TDFS="./.todorc-sync"
	TDFO="./.todorc-opts"
fi

# detect if a specific todolist is given

if [[ IGNORE_T_TODO -eq 0 ]] ; then
	if [[ -n $T_TODO ]] ; then
		TDF="$T_TODO"
		TDFLOCK="$T_TODO.lock"
		TDFA="${T_TODO}-archive.txt"
		TDFC="${T_TODO}rc-display"
		TDFH="${T_TODO}rc-highlight"
		TDFS="${T_TODO}rc-sync"
		TDFO="${T_TODO}rc-opts"
	fi
fi

ulockfile t

# create if not there

if [[ ! -a "$TDFO" ]] ; then
	# create opts file
	cat >"$TDFO" <<EOF
#Auto add with due date (""=disables)
T_AUTO_DUE="+1 day"
EOF

fi

if [[ ! -a "$TDFS" ]] ; then
	# create sync tracking file
	cat >"$TDFS" <<EOF
#!/bin/bash
# Sync API key 
T_SYNCAPI=""
# Sync Server
T_SYNCSERVER="https://mytodos.besbox.com"
# Current list name to filter on
T_SYNCCURLIST=""
# Include lists for sync here
T_SYNCINCLIST=""
# Exclude lists for sync here
T_SYNCEXCLIST=""
# Include source for sync here
T_SYNCINCSOURCE="t"
# Exclude source for sync here
T_SYNCEXCSOURCE=""
# Time of last sync
T_SYNCLAST=0
EOF
fi

if [[ ! -a "$TDF" ]] ; then
	touch "$TDF"
fi

if [[ ! -a "$TDFA" ]] ; then
	touch "$TDFA"
fi

if [[ ! -a "$TDFC" ]] ; then
	# fill config file with default settings
	echo "TAG,PRIO,MARKCOM,IND" >"$TDFC"
fi

if [[ ! -a "$TDFH" ]] ; then
	# fill config file with default settings
	cat >"$TDFH" <<EOF
#!/bin/bash
# config for line highlghts included each time
# adjust colours to match your requirements

tput >/dev/null 2>&1
if [[ \$? -eq 2 && -t 1 ]] ; then

	hl_highlight="\$( tput smso ; tput setab 7 ; tput setaf 1)"
	#hl_highlight="\$(  tput setab 1 ; tput setaf 7)"
	hl_reset="\$( tput rmso ; tput sgr0 )"
	hl_ulineon="\$( tput smul )"
	hl_ulineoff="\$( tput rmul )"
	hl_dimon="\$( tput dim ; tput setaf 6 )"
	hl_dimoff="\$( tput sgr0 )"

	hl_ind="\$( tput setaf 2)"
	hl_completed="\$( tput setaf 8 )"
	hl_cat="\$( tput setaf 2 )"
	hl_due="\$( tput setaf 3 )"
	hl_tag="\$( tput setaf 2)"
	hl_priority="\$( tput setaf 5)"
	hl_dates="\$( tput setaf 7)"
	hl_gannt="\$( tput setaf 6)"
	#hl_note="\$(  tput setab 5 ; tput setaf 7)"
	hl_note="\$( tput smso ; tput setab 7 ; tput setaf 5)"
else
	hl_highlight=""
	hl_reset=""
	hl_ulineon=""
	hl_ulineoff=""
	hl_dimon=""
	hl_dimoff=""
	hl_ind=""
	hl_completed=""
	hl_cat=""
	hl_due=""
	hl_tag=""
	hl_priority=""
	hl_dates=""
	hl_gannt=""
	hl_note=""
fi
EOF
fi
### Apply global flags before anything

	# load line highlights

	. "$TDFH"

	# load sync options

	. "$TDFS"

	# load options

	. "$TDFO"

if [[ $SYNC -ge 1 ]] ; then
	sync
	ulockfilerm t
	exit 0
fi


T_SYNCLAST=$(grep T_SYNCLAST "${TDFS}" | cut -f2 -d'=')

if [[ $GIVEN_GLOBAL_FLAG -eq 1 ]] ; then
        DROPOUT=0

        if [[ $REPORT -eq 1 ]] ; then
		DROPOUT=1
		echo "Show a report"

# TODO display work totals against lines
# TODO calc work totals for each list 
# TODO calc total number of tasks in each list
# TODO list due items
# TODO list over due items


	grep -v "\[D\]" $TDF | ( C=1; while read l ; do 
		
			P_ARRAY=${l#*|}

			IFS='|' read -r -a PROPS <<< "$P_ARRAY"
			echo " - ${PROPS[$P_LISTID]} "
		done ) | sort | uniq -c
		echo "Currently active list: $T_SYNCCURLIST" 

	fi


    	if [[ $SWITCHLIST -eq 1 ]] ; then
		L="${*}"
		if [[ -z "$L" ]] ; then
			echo "Switching currently active list to all"
			sed -i "s/^T_SYNCCURLIST=.*/T_SYNCCURLIST=\"\"/" "$TDFS"
		else
			echo "Switching currently active list to: ${L}"
			sed -i "s/^T_SYNCCURLIST=.*/T_SYNCCURLIST=\"${L}\"/" "$TDFS"
		fi
		echo 
		echo "Lists present here:"

	grep -v "\[D\]" $TDF | ( C=1; while read l ; do 
		
			P_ARRAY=${l#*|}

			IFS='|' read -r -a PROPS <<< "$P_ARRAY"
			echo " - ${PROPS[$P_LISTID]} "
		done ) | sort | uniq -c

		echo 
		echo "Currently active list: $T_SYNCCURLIST" 
		DROPOUT=1
	fi

#	if [[ $COLLAPSE_TREE -ne -1 ]] ; then
#		echo "col=${COLLAPSE_TREE}" >$TDFC
#                DROPOUT=0
#	fi

#	if [[ -n "$SHOWPROPS" ]] ; then
#		echo "display=${SHOWPROPS}" >$TDFC
#                DROPOUT=1
#	fi


	if [[ $MOVETO -gt 0 ]] ; then
                DROPOUT=1
		# move line around

		L="$(sed -n ${1},${1}p ${TDF})"

		sed -i.bak -e "${1}d" ${TDF}

sed -i.bak "${MOVETO}i\
${L}\
" $TDF
	fi

        if [[ $DROPOUT -eq 1 ]] ; then
		ulockfilerm t
		exit 1
	fi
	
fi

# If gannt display is on we must calc the total of the est 
# and worked time so we can scale the line to screen width later

if [[ $SHOWGANNT -eq 1 ]] ; then
	GANNT_EST=0
	GANNT_WORK=0

	ge=$(grep -v "^\[D\]" $TDF | cut -f $((P_ESTTIME+2)) -d'|' | sed s/_//g)
	gw=$(grep -v "^\[D\]" $TDF | cut -f $((P_WORKED+2)) -d'|'|sed s/_//g)

	for c in $ge ; do
		if [[ $c -ne 0 ]] ; then
			GANNT_EST=$((GANNT_EST+c))
		fi
	done

	for c in $gw ; do
		if [[ $c -ne 0 ]] ; then
			GANNT_WORK=$((GANNT_WORK+c))
		fi
	done

	# get the max value to scale against

	[[ $GANNT_EST -gt GANNT_WORK ]] && GANNT_MAX=$GANNT_EST || GANNT_MAX=$GANNT_WORK ;

#	echo $GANNT_EST
#	echo $GANNT_WORK
#	echo $GANNT_MAX

	# get terminal width or default to 30

	GANNT_WIDTH=$(tput cols)
	GANNT_WIDTH=$(($GANNT_WIDTH-30))
	
	if [[ $GANNT_WIDTH -le 0 ]] ; then
		GANNT_WIDTH=40
	fi

	# if max is much lower than width then scale up the step size 
	# calc the step size for render. Use awk as we need possible dec point precis
	if [[ $GANNT_MAX -lt $GANNT_WIDTH ]] ; then
		GANNT_STEP=$( awk "BEGIN { printf \"%.0f\", ${GANNT_WIDTH}/${GANNT_MAX} ; }")
#		echo "Scale up"
		GANNT_UP=1
#		GANNT_WIDTH=40
	else

#		echo "Scale down"
		GANNT_STEP=$( awk "BEGIN { printf \"%.0f\", ${GANNT_MAX}/${GANNT_WIDTH} ; }")
		GANNT_UP=0
	fi


#	echo $GANNT_STEP
	if [[ $GANNT_STEP -eq 0 ]] ; then
		# sometimes gens an invalid number. 
		# do this to stop a div by zero error in awk
		GANNT_STEP=1
	fi
#	echo $GANNT_WIDTH
#	echo "/$GANNT_STEP/"
fi


## Load display config to P_DISP array

D=$(cat $TDFC)

if [[ -n ${T_DISPLAY} ]] ; then
	# pick up the environ var to apply a temp format
	D=$T_DISPLAY
fi

DISP=${DISPLAY1[1]}
IFS=',' read -r -a P_DISP <<< "$D"

# see if we need a list of tasks (ie no arguments were given)

if [[ $# -eq 0 || -n $FILTER ]] ; then
	# if there is a | on the end of the line, dont display the rest. use it to store extra properties


        # if we are going to view the old archive file
        # switch the file names round

	if [[ "$OLDTASKS" -eq 1 ]] ; then 
		TDF="$TDFA"
	fi

	#  take display settings, get a line and display as approp

	# detect if we are doing a temp sort too

	if [[ -n "$SORTON" ]]; then
		# get property field number
		sort_field="P_${SORTON}"
		sort -t '|' -k ${!sort_field} $TDF | ( C=1; while read LINE ; do 
			displayLine $C 
			C=$((C+1)); 
		done )
	else

		cat $TDF  | ( C=1; while read LINE ; do 
				displayLine $C 
				C=$((C+1)); 
			done )
	fi
	if [[ $SETLIST -eq 1  ]] ; then
		echo 
		echo "Lists present here:"

	grep -v "\[D\]" $TDF | ( C=1; while read l ; do 
		
			P_ARRAY=${l#*|}

			IFS='|' read -r -a PROPS <<< "$P_ARRAY"
			echo " - ${PROPS[$P_LISTID]} "
		done ) | sort | uniq -c

		echo 
		echo "Currently active list: $T_SYNCCURLIST" 
	fi
	ulockfilerm t
	exit 1
fi

# do sort if instructed


	if [[ "$1" == "s" ]] ; then
		# sort the list if no indents present

		grep "\-\-" <$TDF >/dev/null 2>&1
		if [[ $? -eq 0 ]] ; then
			echo "Dependancies present. Ignoring sort."
		else
			cat $TDF | sort >$TDF.w
			mv $TDF.w $TDF
		fi
		ulockfilerm t
		exit 3
	fi



# TODO apply the prop changes above
# If the line is an update then apply the update now
# if the line is new then add with those changes

# work out if a single param is a number of a quoted string. means we can handle unquoted and quoted

FIRST_IS_STR=0

if [[ "$1" > "a" ]] ; then
	FIRST_IS_STRING=1
fi

# is there a mark to complete, remove or some other line operation?

if [[ ! $FIRST_IS_STRING ]] ; then

	# if the first is a numeric then lets get the rest of the line
	# it may consist of multiple line numbers to mark as done

	TOMARK="~$(echo "$@" | sed 's/ /~/g')~"

#if [[ $# -eq 1 && ! $FIRST_IS_STRING ]] ; then

### Apply line level flags 

#if [[ $GIVEN_LINE_FLAG ]] ; then

        # if we are going to use the old archive file
        # switch the file names round

	if [[ "$OLDTONEW" -eq 1 ]] ; then 
		OTDF="$TDFA"
		TDFA="$TDF"
		TDF="$OTDF"
	fi

	# as tomark has broken the line up. if this is a note set
	# and it contains numbers we dont want to assume the numbers
	# are lines to assign the note to. lets only take the first 
	# one
	if [[ -n "${NOTE}" ]] ; then
		TOMARK="~$(echo "$TOMARK"|cut -f2 -d'~')~"
	fi

	touch ${TDF}.w
	cat $TDF | ( C=1; while read l ; do 

		OUTPUT=1

		# process any line flags

		if [[  $TOMARK = *"~$C~"* ]] ; then
		#if [[ $C -eq $1 ]] ; then 

			## load the line into array for each property

			# get all the properties

			P_ARRAY=${l#*|}

			IFS='|' read -r -a PROPS <<< "$P_ARRAY"

			E=$MAX_COL ; 
			while [[ $E -ge 0 ]] ; do 
				if [[ -z "${PROPS[$E]}" ]] ; then
					PROPS[$E]="_"
				fi
				E=$((E-1));
			done
		defaultProps 


                       # see if we have a new line number

                       NC=$((C*100))
                       if [[ ${PROPS[$P_SEQ]} -ne $NC ]] ; then
#                            echo "*** Have a new line number to update with ${PROPS[$P_SEQ]} -> ${NC}"
                            PROPS[$P_SEQ]=$NC
                       fi
 
# set sync properties to defaults if not present


#if [[ "${PROPS[$P_SOURCEID]}" == "_" ]] ; then
# 	# default to the config file default
#	PROPS[$P_SOURCEID]="t"
#fi

if [[ "${PROPS[$P_LISTID]}" == "_" ]] ; then
 	# default to the config file default
	PROPS[$P_LISTID]=$T_SYNCCURLIST
fi

if [[ "${PROPS[$P_SYNCID]}" == "_" ]] ; then
	# default to creation date + line
	PROPS[$P_SYNCID]=$( echo "${C}${PROPS[$P_CREATEDATE]}" | sed 's/ //g')
fi

if [[ "${PROPS[$P_SYNCLAST]}" == "_" ]] ; then
	# default to creation date
	PROPS[$P_SYNCLAST]=${PROPS[$P_CREATEDATE]}
fi	


			# get the front of line

			LINE=${l%%|*}

               # if the start of the line does not contain [ then make sure it is added

               	if [[ ${LINE:0:1} != "[" ]] ; then
			LINE="[ ] ${LINE}"
		fi
			# process the flags

			if [[ $EST -ge 0 ]] ; then
				if [[ $EST -eq 0 ]] ; then
					echo "Removing project tracking"
					PROPS[$P_ESTTIME]="_"
					PROPS[$P_PERCENT]="_"
					PROPS[$P_WORKED]="_"
                                	PROPS[$P_WORKSTART]="_"
				else
					# set work estimate
					PROPS[$P_ESTTIME]=$EST
					# reset progress
					PROPS[$P_PERCENT]=0
					PROPS[$P_WORKED]=0
					PROPS[$P_MARKCOM]=0
					PROPS[$P_WORKSTART]="_"
				fi
			fi

                        if [[ $ISREPEAT -ge 0 ]]; then
                                if [[ $ISREPEAT -eq 0 ]] ; then
	                                echo "Marking a repeat period disabled for this task"
                                else
	                                echo "Marking a repeat period of ${ISREPEAT} days"
                                fi
                                PROPS[$P_REPEAT]=$ISREPEAT
                        fi

                        if [[ -n "$ISRTYPE" ]]; then
			    if [[ ${PROPS[$P_REPEAT]} -gt 0 ]] ; then
                                if [[ "$ISRTYPE" = "d" ]] ; then
	                                echo "Marking repeat is based on due date"
					ISRTYPE="0"
                                else
	                                echo "Marking repeat is based on completion"
					ISRTYPE="1"
                                fi
                                PROPS[$P_RTYPE]=$ISRTYPE
			    else
	                                echo "Marking a repeat period disabled for this task"
			    fi
                        fi

                        if [[ -n "$ISTTYPE" ]]; then
                               PROPS[$P_TTYPE]=$ISTTYPE
                        fi
			if [[ $WORK -ge 0 ]] ; then
#	                         echo "est /${PROPS[$P_WORKSTART]}/"
				# record work against the task
				if [[ ${PROPS[$P_ESTTIME]} -gt 0 ]] ; then
					if [[ ${PROPS[$P_MARKCOM]} -gt 0 ]] ; then
						echo "Work recording ignored. Task has been completed"
					else
#	                         echo "start /${PROPS[$P_WORKSTART]}/"
                            if [[ "${PROPS[$P_WORKSTART]}" = ' _ ' ]] ; then
echo "Marking start of work"	                                 
             PROPS[$P_WORKSTART]=$NOW
                                                fi
						PROPS[$P_WORKED]=$((PROPS[${P_WORKED}]+$WORK))
						# recalc percent complete
						PROPS[$P_PERCENT]=$((  200*${PROPS[$P_WORKED]}/${PROPS[$P_ESTTIME]} % 2 + 100*${PROPS[$P_WORKED]}/${PROPS[$P_ESTTIME]}))	
					fi
				else
					PROPS[$P_WORKED]=$((PROPS[${P_WORKED}]+$WORK))
					PROPS[$P_ESTTIME]=$((PROPS[${P_WORKED}]))
					PROPS[$P_PERCENT]=100	
                            		if [[ "${PROPS[$P_WORKSTART]}" = ' _ ' ]] ; then
             					PROPS[$P_WORKSTART]=$NOW
					fi
					echo "Converting to project task and marking start of work"	                                 
				fi
			fi

			if [[ -n "$TAG" ]] ; then
				CURTAG=${PROPS[$P_TAG]}
				if [[ "${TAG:0:1}" = "+" ]]; then
					# add a tag and not replace
					CURTAG="${CURTAG}${TAG:1}"
				elif [[ "${TAG:0:1}" = "-" ]] ; then
					# remove etl_flags
					CURTAG="${CURTAG/${TAG:1}/}"
				else
					CURTAG=$TAG
				fi
				PROPS[$P_TAG]=$CURTAG
			fi

			if [[ $EMAIL -ne 0 ]] ; then
				shift
				PROPS[$P_EMAIL]="${*}"
			fi


			if [[ -n "$HIGHLIGHT" ]] ; then
				PROPS[$P_HIGHLIGHT]=$HIGHLIGHT
			fi


			if [[ $PRIO -ge 0 ]] ; then
				if [[ $PRIO -eq 0 ]] ; then
					PROPS[$P_PRIO]="_"
				else
					PROPS[$P_PRIO]=$PRIO
				fi
			fi

			if [[ -n "$CATEGORY" ]] ; then
				PROPS[$P_CATEGORY]=$CATEGORY
			fi

			if [[ $DUEDATE -eq 1 ]] ; then
				shift
				if [[ "${*}" = "" || "${*}" = "0" ]] ; then
					# disable due date
					echo "Removing due date"
					dateline="_"
				else
					dateline=$(date +%s --date "${*}") 
				fi
				PROPS[$P_DUE]="${dateline}"
			fi

			if [[ $SETLIST -eq 1 ]] ; then
				shift

				if [[ -z "${*}" ]] ; then
					# display list of current lists we have
					PROPS[$P_LISTID]=$T_SYNCCURLIST

				else
					# replace spaces with a dash
					PROPS[$P_LISTID]="$(echo "${*}" | sed 's/ /-/g')"
				fi
			fi

if [[ $DEPENDS -gt 0 ]]; then
#Change dependancy
DID="${*}"

	# find out indent of parent

	CINDENT=`sed "${DEPENDS}q;d" $TDF | cut -b5- | cut -f1 -d' '`

	if [[ ${CINDENT:0:1} != "-" ]] ; then
		# not indented
		CINDENT=""
	fi

	CINDENT="${CINDENT}--+"

    # Get local parent id which is created date (after sync it can change to real task id)
	PTID=$(sed "${DEPENDS}q;d" $TDF | cut -f2 -d'|')

	#echo $CINDENT
	PROPS[${P_DEPENDID}]=${PTID}
	LINE=$(echo "$LINE"/ | sed "s/\] /\] ${CINDENT} /")
	
fi


			if [[ $NOTE -eq 1 ]] ; then
				shift
				noteline="${*}"
                                if [[ -n "${*}" ]] ; then 
					if [[ "${noteline:0:1}" == "+" ]] ; then
						# add to existing notes
						noteline="${noteline:1}"
						PROPS[$P_NOTE]="${PROPS[$P_NOTE]} ~ ${noteline}"
					else
						PROPS[$P_NOTE]="${noteline}"
					fi
				else 
					# clear note when giving no string
					PROPS[$P_NOTE]="_"
				fi
			fi

			if [[ $UNMARK -eq 1 ]] ; then
				LINE="[ ] ${LINE:4}"
			fi

			if [[ $OLDTONEW -eq 1 ]] ; then
				LINE="[ ] ${LINE:4}"
				echo "$LINE" >>${TDFA}
				# we've handled output above so skip that below
				OUTPUT=0 
			fi

			if [[ $REINDENT -ge 0 ]] ; then
				# Reindent the line(s)

				# remove indent if present

#				echo $LINE
#				echo $LINE | sed 's/\] [--+]* /\] /'

				# build new indent level

				IL=0
				IT=""

				while [[ $IL -lt $REINDENT ]] ; do
					IT="${IT}--+"
					IL=$((IL+1))
				done
#				echo $IT
	
				if [[ ${LINE:4:1} != "-" ]] ; then
					# not indented. need to insert
					LINE=$(echo $LINE | sed "s/\] /\] ${IT} /")
				else
					# replace the current indent with the new one (easy)
					LINE=$(echo $LINE | sed "s/\] [--+]* /\] ${IT} /")
				fi
				

			fi



			# Handle mark as done

			if [[  $OPTIND -eq 1 ]] ; then
				if [[ "${PROPS[$P_WORKED]}" == " 0 " ]] ; then
					echo "Can't complete a project task if no work assigned!"
			else
	
				if [[ ${LINE:1:1} == "D" ]] ; then
# already marked as soft deleted so dont bring back
echo "This item has been deleted"
else

		if [[ "${PROPS[$P_LISTID]}" != " $T_SYNCCURLIST " ]] ; then
			echo "Item not on this list!"
		else
				# marked as done already?
				if [[ ${LINE:1:1} == "*" ]] ; then


					# mark completed, but if sync is configured just hide it so we can sync to other clients

						# not configured so do local archive
						# yes, get rid of line?
						OUTPUT=0
						# if archiving of old tasks is set then do that
						if [[ $TOARCHIVE -eq 1 ]] ; then
							echo "Archive to ${TDFA}: $LINE"
							echo "$l" >>${TDFA} 
						fi
						if [[ -n "$T_SYNCAPI" ]] ; then
							LINE="[D] ${LINE:4}"
							OUTPUT=1
						fi
					#fi
					#fi
				else
					# if a repeating task then reset required props

 					if [[ ${PROPS[$P_REPEAT]} -gt 0 ]] ; then
						PROPS[$P_MARKCOM]="$(date +%s)"
                                                # calc unix timestamp of days to add
                                                REPDAYS=$((PROPS[$P_REPEAT]*86400))
if [[ "${PROPS[$P_RTYPE]}" = " 0 " ]] ; then
						echo "A repeating task, calculating ${PROPS[$P_REPEAT]} days after next due date"
   						PROPS[$P_DUE]=$((PROPS[$P_DUE]+$REPDAYS))
else
						echo "A repeating task, calculating ${PROPS[$P_REPEAT]} days after completion"
   						PROPS[$P_DUE]=$((PROPS[$P_MARKCOM]+$REPDAYS))
fi
						OUTPUT=1
					else
						# mark as done
						
						LINE="[*] ${LINE:4}"
						echo "Done: $LINE"

						# handle the properties

						PROPS[$P_MARKCOM]="$(date +%s)"

						# if there is an attached email then send an email

						if [[ -n ${PROPS[$P_EMAIL]} ]] ; then
						if [[ "${PROPS[$P_EMAIL]}" -ne "_" ]] ; then
							if [[ -n "${T_SENDER}" ]]  ; then
								from="-f ${T_SENDER}"
							else
								from=""
							fi
							echo "Subject: DONE $LINE" | sendmail ${from} ${PROPS[$P_EMAIL]} >/dev/null 2>&1
						fi
						fi
					fi
		fi
				fi
			fi
			fi
fi

PROPS[$P_SYNCLAST]=${NOW}


			# Reconstruct line from array and output

			l=$LINE

			for el in "${PROPS[@]}" ; do 
#				echo "el $el"
#TODO this whitespace removal wipes out note data but need it for other fields
#				el=${el#* }
#				el=${el%% *}
el=$(echo "$el" |sed 's/^ *//;s/ *$//')
#				echo "el $el"
				l="$l | $el"
			done
		fi 

		# output original or reconstructed line
		if [[ $OUTPUT -eq 1 ]] ; then
			echo "$l" >>${TDF}.w 
		fi

#		echo "line $l"
		C=$((C+1));
         	done   
	)

	mv -f ${TDF}.w ${TDF} >/dev/null 2>&1
#fi
	ulockfilerm t
	exit 2
fi



if [[ -n "${T_AUTO_DUE}" ]] ; then
	auto_date=$(date +%s --date "${T_AUTO_DUE}") 
else
	auto_date="_"
fi



if [[ $DEPENDS -ne 0 ]] ; then
	# if it needs to depend on something else then insert the line

	# find out indent of parent

	CINDENT=`sed "${DEPENDS}q;d" $TDF | cut -b5- | cut -f1 -d' '`

	if [[ ${CINDENT:0:1} != "-" ]] ; then
		# not indented
		CINDENT=""
	fi

        # get line number of parent

	PLINE=$(sed "${DEPENDS}q;d" $TDF | cut -f${P_SEQ} -d'|')
        PLINE=$((PLINE+50))
	#echo "Parent line number $PLINE"

	# TODO cant add one to the last item
	# TODO if beyond end of file then not added
    # Get local parent id which is created date (after sync it can change to real task id)
	PTID=$(sed "${DEPENDS}q;d" $TDF | cut -f2 -d'|')

	LINEINFILE=`cat $TDF |wc -l`

	if [[ $DEPENDS -ge $LINEINFILE ]] ; then
		echo "[ ] ${CINDENT}--+ $* | ${NOW} | ${USER} | _ | _ | _ | _ | _ | _ | _ | ${auto_date} | _ | _ | _ | _ | _ | ${PTID} | _ | ${T_SYNCCURLIST} | ${NOW} | ${NOW} | t | ${PLINE} | _ | _ | _ | _ | _ |"  >>$TDF
	else

	# while parent has other children skip them

	DEPENDS=$((DEPENDS + 1 ))
sed -i.bak "${DEPENDS}i\
\[ \] ${CINDENT}--+ ${*} | ${NOW} | ${USER} | _ | _ | _ | _ | _ | _ | _ | ${auto_date} | _ | _ | _ | _ | _ | ${PTID} | _ | ${T_SYNCCURLIST} | ${NOW} | ${NOW} | t | _ | _ | _ | _ | _ | \
" $TDF
fi
else

	# no, so lets add to the end
	LINEINFILE=`cat $TDF |wc -l`
	echo $((LINEINFILE+1))>/dev/stderr
        LINEINFILE=$((LINEINFILE*100))
        #echo "New Line number should be $LINEINFILE"
	
		# add | at the end of the line and use it to record who add
		l="[ ] ${*} | ${NOW} | ${USER}  | _ | _ | _ | _ | _ | _ | _ | ${auto_date} | _ | _ | _ | _ | _ | _ | _ | ${T_SYNCCURLIST} | ${NOW} | ${NOW} | t | $LINEINFILE | _ | _ | _ | _ | _ | _ |" 

	#		LINE=${l%%|*}
		echo $l>>$TDF	
#	syncupload

	fi

	
#fi

ulockfilerm t
exit 0
# eof
