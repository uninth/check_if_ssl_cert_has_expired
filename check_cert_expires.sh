#!/bin/bash
#
# Quick and dirty test if ssl certs are about to expire. Requires GNU date
# and mutt. Tested on OSX (use brew to install gnudate and mutt) and Linux
#

RCPT=user@tld
NOTIFY_IF_LESS_THAN_DAYS=30

MYNAME=`basename $0`
MY_LOGFILE=./${MYNAME}.log
VERBOSE=FALSE

# functions
function is_expired()
{
	local ADDR=$1
	local RCPT=$2
	local DAYS_BEFORE=$3
	local NOTIFY="No"
	
	NOT_AFTER=`echo |
		openssl s_client -connect ${ADDR}:443 2>/dev/null |
		openssl x509 -noout -dates 2>/dev/null |
		sed '/notAfter/!d; s/.*=//'|
			awk '
			{
				print $2 " " $1 " " $4
			}'` 
	NOW=`date +"%e %b %Y"`
	DAYS=`datediff "${NOT_AFTER}" "${NOW}"`
	ISSUER=`get_issuer $ADDR`

	D=`echo $DAYS|awk '{print $1}'`
	if [ -z "$NOT_AFTER" ]; then
		NOTIFY="Error"
	else
		if [ "${D}" -gt "${DAYS_BEFORE}" ]; then
			NOTIFY="No"
		else
			NOTIFY="Yes"
		fi
	fi
	echo "$ADDR;$ISSUER;$NOT_AFTER;$DAYS;$RCPT;$NOTIFY"
}


function get_issuer()
{
	local ADDR=$1
	local ISSUER=""
	ISSUER=`echo |openssl s_client -host ${ADDR} -port 443 -prexit -showcerts 2>/dev/null|
	sed '/issuer/!d; s/.*=//'|head -1`
	case $ISSUER in
		"")	ISSUER="failed to read certificate"
			;;
		*)	:
	esac
	echo $ISSUER
}


datediff() {
	case `uname` in
		Linux)	date=date
			;;
		*)		date=gdate
			;;
	esac
    d1=$($date -d "$1" +%s)
    d2=$($date -d "$2" +%s)
    echo $(( (d1 - d2) / 86400 )) days
}


function logit() {
# purpose     : Timestamp output
# arguments   : Line og stream
# return value: None
# see also    :
    LOGIT_NOW="`date '+%H:%M:%S (%d/%m)'`"
    STRING="$*"

    if [ -n "${STRING}" ]; then
        $echo "${LOGIT_NOW} ${STRING}" >> ${MY_LOGFILE}
        if [ "${VERBOSE}" = "TRUE" ]; then
            $echo "${LOGIT_NOW} ${STRING}"
        fi
    else
        while read LINE
        do
            if [ -n "${LINE}" ]; then
                $echo "${LOGIT_NOW} ${LINE}" >> ${MY_LOGFILE}
                if [ "${VERBOSE}" = "TRUE" ]; then
                    $echo "${LOGIT_NOW} ${LINE}"
                fi
            else
                $echo "" >> ${MY_LOGFILE}
            fi
        done
    fi
}


function assert () {

    E_PARAM_ERR=98 
    E_ASSERT_FAILED=99 
    if [ -z "$2" ]; then        #  Not enough parameters passed to assert() function. 
        return $E_PARAM_ERR     #  No damage done. 
    fi  
    if [ ! "$1" ]; then 
    # Give name of file and line number. 
        echo "Assertion failed:  \"$1\" File \"${BASH_SOURCE[1]}\", line ${BASH_LINENO[0]}"
        echo "  $2"
        exit $E_ASSERT_FAILED 
    # else 
    #   return 
    #   and continue executing the script. 
    fi  
}

function usage() {

echo $*
cat << EOF
    Usage: `basename $0` [-v] -f file

    File is a text file with the following layout

	fqdn/address  contact days_before_warning
	1.2.3.4	user@example.com	10

	Check 1.2.3.4 if the cert expires within 10 days show warning. user@example.com is just for information

EOF
    exit 2
}

function clean_f () {

    $echo trapped
	rm -f $CSVTMP $REPORTTMP
	exit 1
}

function makecsv()
{
	echo "IP/FQDN;Issuer;Expires on;Dates left;Notification to;Notify" > ${CSVTMP}
	while read SERVER RCPT DAYS_BEFORE
	do
			is_expired "${SERVER}" "$RCPT" "$DAYS_BEFORE"
		done < "${FILE}" | awk -F';' '
		{
			printf("%s;%s;%s;%s;%s;%s\n", $1, $2, $3, $4, $5, $6)
		}' >> $CSVTMP

# markdown version
#		printf "| %-30s | %-50s | %-20s | %-10s | %20s | %6s |\n" "IP/FQDN" "Issuer" "Expires on" "Dates left" "Notification to" "Notify"	>> $REPORTTMP
#		printf "| %-30s | %-50s | %-20s | %-10s | %-20s | %-6s |\n" "----" "----" "----" "----" "----" "----"									>> $REPORTTMP
#		while read SERVER RCPT DAYS_BEFORE
#		do
#			is_expired "${SERVER}" "$RCPT" "$DAYS_BEFORE"
#		done < "${FILE}" | awk -F';' '
#		{
#			printf("| %30s | %-50s | %20s | %10s | %20s | %6s |\n", $1, $2, $3, $4, $5, $6)
#		}' >> $REPORTTMP
#
#		cat $REPORTTMP

}

function makereport()
{
	TITLE="SSL expire report"
	REPORTTMP_TIME="`export LANG=en_UK.UTF-8; /bin/date +'%B %d, %Y at %H:%M:%S'`"

	cat ${CSVTMP} | (
cat << EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2//EN">
<HTML>
<HEAD>
<META HTTP-EQUIV="CONTENT-TYPE" CONTENT="text/html; charset=utf8">
<TITLE>$TITLE</TITLE>
<style TYPE="text/css">
.unistyle table { border-collapse: collapse; text-align: left; width: 100%; }
.unistyle {font: normal 12px/150% Arial, Helvetica, sans-serif; background: #fff; overflow: hidden; border: 1px solid #006699; -webkit-border-radius: 3px; -moz-border-radius: 3px; border-radius: 3px; }
.unistyle table td,
.unistyle table th { padding: 3px 10px; }
.unistyle table thead th {background:-webkit-gradient( linear, left top, left bottom, color-stop(0.05, #006699), color-stop(1, #00557F) );background:-moz-linear-gradient( center top, #006699 5%, #00557F 100% );filter:progid:DXImageTransform.Microsoft.gradient(startColorstr='#006699', endColorstr='#00557F');background-color:#006699; color:#FFFFFF; font-size: 15px; font-weight: bold; border-left: 1px solid #0070A8; }.unistyle table thead th:first-child { border: none; }
.unistyle table tbody td { color: #00496B; border-left: 1px solid #E1EEF4;font-size: 12px;font-weight: normal; }
.unistyle table tbody .alt td { background: #E1EEF4; color: #00496B; }
.unistyle table tbody .bad td { background: #FFF8C6; color: #00496B; }
.unistyle table tbody td:first-child { border-left: none; }
.unistyle table tbody tr:last-child td { border-bottom: none; }
</style>
</HEAD>
<BODY>
<TABLE FRAME="VOID" CELLSPACING="1" COLS="1" RULES="NONE" BORDER="1"><TBODY><TR><TD>
<H1>$TITLE</H1>
<P>SSL expire bot, running on `hostname -f` as `whoami` on `date`.
<br/>
</P>
<div class="unistyle">
<table>
<thead><tr>
<th>IP/FQDN</th>
<th>Issuer</th>
<th>Expires on</th>
<th>Dates left</th>
<th>Notification to</th>
<th>Notify</th>
</tr></thead>
<tbody>
EOF


        awk -F';' '
        BEGIN {
            ALT = 0 ;
        }
		$1 == "IP/FQDN" { next; }
        {
            if ($6 != "No")
            {
				printf("<tr class=\"bad\"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", $1, $2, $3, $4, $5, $6)
                if (ALT == 0)
                {
                    ALT = 1;
                }
                next
            }

            if (ALT == 0)
            {
				printf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", $1, $2, $3, $4, $5, $6)
                ALT = 1
                next
            }
            else
            {
				printf("<tr class=\"alt\"><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", $1, $2, $3, $4, $5, $6)
                ALT = 0
                next
            }
        }
    '

    cat << EOF
</tbody>
</table>
</div>
</P>
</body></HTML>
</HTML>
EOF
	)  > $REPORTTMP
}


function main()
{
    # check on how to suppress newline (found in an Oracle installation script ca 1992)
    echo="/bin/echo"
    case ${N}$C in
        "") if $echo "\c" | grep c >/dev/null 2>&1; then
            N='-n'
        else
            C='\c'
        fi ;;
    esac

    #
    # Process arguments
    #
    while getopts vf:hr: opt
    do
    case $opt in
        v)  VERBOSE=TRUE
        ;;
        f)  FILE=$OPTARG
        ;;
		r)	RCPT=$OPTARG
		;;
        h|*)  usage
            exit
        ;;
    esac
    done
    shift `expr $OPTIND - 1`

	if [ ! -f "${FILE}" ]; then
		echo "error: file '$FILE' not found"; exit
	fi

	# make csv
	CSVTMP=`mktemp`.csv
	makecsv

   	REPORTTMP=`mktemp`.html
	makereport

	# send mail
	mutt -e "set content_type=text/html" -s "SSL report" -- "${RCPT}" < ${REPORTTMP}

	# save report some where ...
	# cp ${REPORTTMP} /var/www/html/ ... 

	# cleanup
	rm -f $CSVTMP $REPORTTMP

	exit 0
}

################################################################################
# Main
################################################################################
#
# clean up on trap(s)
#
trap clean_f 1 2 3 13 15

main $*


################################################################################
#
#  Modified BSD License
#  ====================
#
#  Copyright © 2019, Niels Thomas Haugård
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  3. Neither the name of the organisation  DEiC/i2.dk nor the
#     names of its contributors may be used to endorse or promote products
#     derived from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL NIELS THOMAS HAUGÅRD BE LIABLE FOR ANY
#  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
################################################################################
