#!/bin/bash

#sched.sh
#author: 	Vsevolod Geraskin 
#created:	May 14, 2012
#last revision: May 24, 2012
#requirements:	uuencode,basename,date,md5sum,sed,awk,sendmail

#The cron email program is written entirely in bash shell script and is able to do the following:
#	• specify date and time of the cron job, email address of the recipient, and the attachment file;
#	• validate the above user-entered variables;
#	• format the email in a proper form;
#	• identify the type of email attachment and correctly specify mimetype (proper attachments instead of inline attachments are sent);
#	• and schedule multiple cron jobs (created mail messages and scripts are identified by date and time).

#appends a line (2nd parameter) to a file (1st parameter) 
function appendfile() {
    echo "$2">>$1;
}

#creates mail file
function createmailfile() {
	#current path
	mypath=`pwd`
	
	#when are we running our cron job, also used in created file names
	datesent=`date -d "$cdate $ctime"`
	minute=`date -d "$cdate $ctime" +%M`
	hour=`date -d "$cdate $ctime" +%H`
	monthday=`date -d "$cdate $ctime" +%d`
	month=`date -d "$cdate $ctime" +%m`
	weekday=`date -d "$cdate $ctime" +%w`
	
	#email messages need a boundary between sections
	boundary=`date +%s|md5sum`
	boundary=${boundary:0:32}
	
	#determining mime type of the file based on extension
	mimetype=`gnomevfs-info -s $cfile | awk '{FS=":"} /MIME type/ {gsub(/^[ \t]+|[ \t]+$/, "",$2); print $2}'`
	
	#temporary file that converts attachment to base64 string
	tempfile="${mypath}/${minute}${hour}${monthday}${month}${weekday}.temp"
	rm -f $tempfile

	filename=`basename $cfile`
	cat $cfile|uuencode --base64 $filename>$tempfile #encoding attachment as base64
	sed -i -e '1,1d' -e '$d' $tempfile #removing first and last line from $tempfile
	attachdata=`cat $tempfile`

	rm -f $tempfile
	
	#file that stores email message
	mailfile="${mypath}/${minute}${hour}${monthday}${month}${weekday}.mail"
	rm -f $mailfile

	#creating mail message file
	appendfile $mailfile "From: youremail@email.com"
	appendfile $mailfile "To: $cemail"
	appendfile $mailfile "Reply-To: youremail@email.com"
	appendfile $mailfile "Subject: Test Cron Email"
	appendfile $mailfile "Content-Type: multipart/mixed; boundary=\""$boundary"\""
	appendfile $mailfile ""
	appendfile $mailfile "This is a MIME formatted message.  If you see this text it means that your"
	appendfile $mailfile "email software does not support MIME formatted messages."
	appendfile $mailfile ""
	appendfile $mailfile "--$boundary"
	appendfile $mailfile "Content-Type: text/plain; charset=ISO-8859-1; format=flowed"
	appendfile $mailfile "Content-Transfer-Encoding: 7bit"
	appendfile $mailfile "Content-Disposition: inline"
	appendfile $mailfile ""
	appendfile $mailfile "This email was sent on $datesent with $filename as attachment."
	appendfile $mailfile ""
	appendfile $mailfile ""
	appendfile $mailfile "--$boundary"
	appendfile $mailfile "Content-Type: $mimetype; name=\"$filename\""
	appendfile $mailfile "Content-Transfer-Encoding: base64"
	appendfile $mailfile "Content-Disposition: attachment; filename=\"$filename\";"
	appendfile $mailfile ""
	appendfile $mailfile "$attachdata"
	appendfile $mailfile ""
	appendfile $mailfile ""
	appendfile $mailfile "--$boundary--"
	appendfile $mailfile ""
	appendfile $mailfile ""
}

#creates cron script
function createcronshell() {
	#cron script file
	cronfile="${mypath}/${minute}${hour}${monthday}${month}${weekday}.cron"
	rm -f $cronfile

	appendfile $cronfile "#!/bin/bash"
	appendfile $cronfile ""
	appendfile $cronfile "cat $mailfile|sendmail -t"

	#allowing any user to execute shell script (this is dangerous!)
	chmod 777 $cronfile
}

#adds a line to crontab, scheduling our cron script to run on specified date and time
function addtocrontab() {
	crontab="/etc/crontab"
	cronline="${minute} ${hour} ${monthday} ${month} ${weekday} root ${cronfile}"
	echo "		adding to crontab: $cronline"
	appendfile $crontab "$cronline"
}

#default values for variables to be changed by a user
cdate=`date +%m/%d/%Y`
ctime=`date +%H:%M`
cemail='youremail@email.com'
cfile='test'

#main program loop
while true

do
	clear
	#default menu
	 cat << 'SCHEDMENU'
	Email Cron Scheduler by Vsevolod Geraskin

 	set date ............... (D)		
 	set email .............. (E)		
 	set attachement ........ (A)	
 	schedule cron .......... (S)
 	quit ................... (Q)
SCHEDMENU
	
	#current values requiring user input
	echo 
	echo -n '	current set date:          '
	if [ "$cdate" != '' ] && [ "$ctime" != '' ]
		then
			date -d "$cdate $ctime"
		else
			echo
	fi

	echo -n '	current set email: 	   '
	echo $cemail
	echo -n '	current set attachment:    '
	echo $cfile
	echo 
	echo -n '		please enter a letter, then press return key >> '

	read ltr rest

	case $ltr in
		[Dd])	echo 
			echo -n '		please enter date (mm/dd/yyyy hh:mm) >> '
			read cdate ctime rest
			date -d "$cdate $ctime"
			
			#date validation using built-in function
			if [ $? -eq 1 ] || [ "$cdate" == '' ] || [ "$ctime" == '' ]
				then  
					echo '		error: date is invalid'
					cdate=''
					ctime=''				
			fi	 ;;

		[Ee])	echo 
			echo -n '		please enter recipients email >> '
			read cemail rest

			echo "$cemail" | grep '@'
			
			#very basic email validation, only looking for @ char
			if [ $? -eq 1 ]
				then  
					echo '		error: email is invalid'
					cemail=''
			fi	 ;;

		[Aa])	echo 
			echo -n '		please enter attachment file path >> '
			read cfile rest
			
			#checking if attachment file exists
			if [ ! -f "$cfile" ]
				then 
					echo '		error: file does not exist'
					cfile=''
			fi	;;


		[Ss])	if [ "$cdate" != '' ] && [ "$ctime" != '' ] && [ "$cemail" != '' ] && [ "$cfile" != '' ]
				then
					#if all variables are set, do the following
					createmailfile
					echo '		mail file created'
					createcronshell
					echo '		cron shell created'
					addtocrontab
					echo '		crontab job added'
				else
					echo '		error: one of the variables is not set'
			fi	;;
		[Qq])	exit	 ;;
		*)	echo ; echo unrecognized choice: $ltr  ;;
	esac
	echo ; echo -n '		press enter to continue.....'
	read rest
done
