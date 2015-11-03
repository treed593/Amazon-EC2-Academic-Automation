#!/bin/bash
# =============================================================================
# aws_for_students -- A utility for creating AWS EC2 student accounts		  #
#                                                                             #
# Written By:   Trevor Reed  (treed593)                                       #
#               treed593@gmail.com    										  #
#										      					              #
# Contributors: Mike Boylan (mboylan)										  #
#																			  #
# Purpose: This script will create a personal Amazon EC2 instance for each	  #
# 		   student in a class. Once the instances are created, the student	  #
#		   will have a user account created for them on their personal	  	  #
#		   instance. The professor will also have an account on each server	  #
#		   all logins will be conducted with SSH private keys. The students	  #
#		   keys will be created on their servers the professors will be		  #
#		   created beforehand and copied to each server, to standardize their #
#		   key.																  #
# 																		      #
# License: This content is released under the MIT License. The full text of   #
#          this license can be found at 									  #
#          https://trevorreed.com/aws-script-license.txt					  #
#  																			  #
# Change Log:																  #
#																	 		  #
# =============================================================================


# Some basic usage information if run with a help flag...
if [[ $1 == "--help" || $1 == "-h" ]]; then
	echo ""
	echo "This utility creates AWS EC2 instances for students."
	echo ""
	echo "Usage: aws_for_students /path/to/student/file.lst /path/to/key/file.pem discipline course section term instructor expiredate"
	echo "Example: aws_for_students 3456a.txt ubuntu.pem INFS 3456 A1 201380 reed 2013-04-10"
	echo ""
	exit 0
fi

# Check to make sure we have all of the variables we need
if [[ $# -ne 8 ]]; then
	echo ""
	echo "ERROR: Missing one or more required parameters..."
	echo "Usage: aws_for_students /path/to/student/file.lst /path/to/key/file.pem discipline course section term instructor expiredate"
	echo "Example: aws_for_students 3456a.txt ubuntu.pem INFS 3456 A1 201380 reed 2013-04-10"
	echo ""
	exit 1
fi

# Check that $1 is a valid file...
if [[ ! -f $1 ]]; then
	echo ""
	echo "ERROR: File $1 not found..."
	echo ""
	exit 1
fi


# ============================================================================
#               		      Global Variables    							 #
#												                             #
# ============================================================================
# Full paths to commands used
mutt=/usr/bin/mutt
ec2runinstances=/usr/local/ec2/ec2-api-tools-1.6.12.2/bin/ec2-run-instances
ec2createtags=/usr/local/ec2/ec2-api-tools-1.6.12.2/bin/ec2-create-tags
TIMESTAMP=$( date )

# Variables entered on the command line
KEYFILE=$2
DISCIPLINE=$3
COURSE=$4
SECTION=$5
TERM=$6
INSTRUCTOR=$7
EXPIREDATE=$8

# The script should check if windows or linux and be able to create and setup both

# ============================================================================
#               		  Create Storage Folders     						 #
#												                             #
# ============================================================================
mkdir /root/$DISCIPLINE$COURSE$SECTION$TERM
mkdir /root/$DISCIPLINE$COURSE$SECTION$TERM/keys
mkdir /root/$DISCIPLINE$COURSE$SECTION$TERM/mailings
mkdir /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles
touch /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/EC2RUNFILE.txt
touch /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/EC2TAGFILE.txt
touch /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/err.log

exec 2>/root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/err.log


# ============================================================================
#               		  Create AWS Instances 								 #
#												                             #
# ============================================================================
IFS=","
OLDIFS=$IFS
EC2TAGFILE=/root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/EC2TAGFILE.txt
NAMEFILE=$1
NOW=$(date)

#Log beginning of Script
echo "$TIMESTAMP:Script started for $DISCIPLINE$COURSE-$SECTION for term $TERM" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt

while read USER STUDENT STID NUM
do
EC2RUNFILE=/root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/EC2RUNFILE-$USER.txt
echo "Creating machine for $USER named $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu" | tee -a /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/createdmachines.txt
$ec2runinstances ami-b57e31d0 -t t2.micro -k Acad_Master -g sg-dc094bbb -s subnet-634d0748 --associate-public-ip-address true -H >> $EC2RUNFILE

INSTANCE_ID=$(cat $EC2RUNFILE | awk '/INSTANCE/ {print $2};')
$ec2createtags $INSTANCE_ID --tag "Name=$TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu" --tag "Course=$DISCIPLINE$COURSE" --tag "Professor=$INSTRUCTOR" --tag "Student=$STUDENT" --tag "StudentID=$STID" --tag "ExpireDate=$EXPIREDATE" --tag "Created=$NOW"  >> $EC2TAGFILE
echo "Waiting for 2 minutes for the Instance to start"
sleep 120
HOST_NAME=$(ec2-describe-instances $INSTANCE_ID | awk '/amazonaws.com/ {print $4}')

# write Information on each host to AWS-Names.txt. This file serves as the namefile for the next step in the script
echo $USER,$STUDENT,$INSTRUCTOR,$INSTANCE_ID,$HOST_NAME >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Names.txt
#Write Information on each host to AWS-Log.txt. This file serves as the Log with Timestamping of each machine.
echo "$TIMESTAMP:Created machine for $USER:$STUDENT the hostname is $HOST_NAME" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
done < $NAMEFILE


IFS=$OLDIFS


# ============================================================================
#               		        Set Hostname 			      				 #
#						  Create Users and Key Files                         #
# ============================================================================

IFS=","
OLDIFS=$IFS
MACFILE=/root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Names.txt
NOW=$(date)

	echo "Waiting 3 minutes before trying SSH..."
	sleep 180
while read USER STUDENT INSTRUCTOR INSTANCE HOST
do
	echo "Changing hostname for $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu"
	ssh -n -t -t -o StrictHostKeyChecking=no ubuntu@$HOST -i $KEYFILE 'sudo sed -i '/HOSTNAME=/cHOSTNAME=$TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu' /etc/sysconfig/network" > /dev/null 2>&1'
	echo "$TIMESTAMP:Set Hostname for $HOST to $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
	echo "Creating user $USER for $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
	# Add user groups to control permissions
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo groupadd students"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo groupadd professors"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo useradd -c \"$STUDENT\" -g students -s /bin/bash -m -d /home/$USER $USER"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo useradd -c \"$INSTRUCTOR\" -g professors -G students -s /bin/bash -m -d /home/$INSTRUCTOR $INSTRUCTOR"
	# Create the Key Pair for the Student
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "ssh-keygen -q -b 2048 -t rsa -C "$USER" -N \"\" -f /home/ubuntu/$USER.pem"
	# Setup .ssh directories
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo mkdir /home/$USER/.ssh"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo mkdir /home/$INSTRUCTOR/.ssh"
	# Set ownership of the .ssh directores and set permissions
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chown $USER:students /home/$USER/.ssh"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chown $INSTRUCTOR:professors /home/$INSTRUCTOR/.ssh"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chmod 700 /home/$USER/.ssh"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chmod 700 /home/$INSTRUCTOR/.ssh"
	# Copy the new private key to the student .ssh directory
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo cp /home/ubuntu/$USER.pem.pub /home/$USER/.ssh/authorized_keys"
	# Transfer the instructors key from EC2Box
	scp -o StrictHostKeyChecking=no -i $KEYFILE /root/keys/$INSTRUCTOR/$INSTRUCTOR.pem.pub ubuntu@$HOST:/home/ubuntu/$INSTRUCTOR.pem.pub
	# Copy the instructor key to the authorized_keys file
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo cp /home/ubuntu/$INSTRUCTOR.pem.pub /home/$INSTRUCTOR/.ssh/authorized_keys"
	# Change ownership of the authorized_keys files and set permissions
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chown $USER:students /home/$USER/.ssh/authorized_keys"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chown $INSTRUCTOR:professors /home/$INSTRUCTOR/.ssh/authorized_keys"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chmod 600 /home/$USER/.ssh/authorized_keys"
	ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST "sudo chmod 600 /home/$INSTRUCTOR/.ssh/authorized_keys"
	# Create a local directory to store Key Backups
	mkdir /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER
	# Copy keys from remote host to EC2Box
	scp -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST:/home/ubuntu/$USER.pem /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.pem
	scp -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOST:/home/ubuntu/$USER.pem.pub /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.pem.pub
	echo "  Converting Private Key..."
	echo $USER
	# Convert the private key from .pem to .ppk
	puttygen /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.pem -o /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.ppk

# Log Key Creation for each user
echo "$TIMESTAMP:Created User $USER on $HOST" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt

MAILFILE='/root/'$DISCIPLINE$COURSE$SECTION$TERM'/mailings/'$USER'.mail'
PUBLICKEY=$(cat /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.pem.pub)
NOTIFY=$USER@mail.example.edu
CC=$INSTRUCTOR@example.edu
BLIND=admins-server@example.edu
ADMIN=admins-server@example.edu
SERVERS=$(ls /root/$DISCIPLINE$COURSE$SECTION$TERM/mailings)
REPORTFILE='/root/'$DISCIPLINE$COURSE$SECTION$TERM'/mailings/adminreport.mail'


touch /root/$DISCIPLINE$COURSE$SECTION$TERM/mailings/$USER.mail
echo "Your account for $DISCIPLINE$COURSE-$SECTION has been created.
Hostname: $HOST
Username: $USER

This account will expire on: $EXPIREDATE

You can access the server via PuTTY on Windows or SSH on Mac.

NOTE: You must use key-based authentication! You will find your private key attached.

Your corresponding public key has been installed on the host already.
	Your Public Key is:
	$PUBLICKEY

Please do not reply to this email! Contact your professor ($INSTRUCTOR@example.edu) if you have problems accessing your account." >> $MAILFILE

echo "     Sending mail to $NOTIFY..."

$mutt -s "[$DISCIPLINE-$COURSE$SECTION] Student account setup information for $USER" -b $BLIND -c $CC -a /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.pem -a /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER/$USER.ppk -a /root/attachments/UsingPuTTYtoLoginWindows.pdf -a /root/attachments/UsingsshtoLoginMac.pdf -a /root/attachments/SSHBuilder.zip -- $NOTIFY < $MAILFILE

#Log email to each user
echo "$TIMESTAMP:Sent email to $USER with Private key and instructions to login" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt

done < $MACFILE
IFS=$OLDIFS


echo "     Done."
echo ""
echo "Done."
echo ""
# ============================================================================
#               		  Email ADMINS the Logfile							 #
#												                             #
# ============================================================================
#Echo close of Script
echo "$TIMESTAMP:Script ended successfully, sending log to $ADMIN" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
echo "		Sending script log..."

touch /root/$DISCIPLINE$COURSE$SECTION$TERM/mailings/adminreport.mail
echo " The following emails were sent to Students:
	$SERVERS" >> $REPORTFILE

	$mutt -s "[$DISCIPLINE-$COURSE$SECTION] EC2 Instance Creation Report" -a /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt -- $ADMIN < $REPORTFILE
echo "Done."
