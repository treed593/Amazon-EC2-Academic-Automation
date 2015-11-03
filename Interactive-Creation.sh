#!/bin/bash

# Place readme here

# Some basic usage information if run with a help flag...
if [[ $1 == "--help" || $1 == "-h" ]]; then
  # write help information
	exit 0
fi

# Important Global Variables
IFS=","
OLDIFS=$IFS

# Full paths to commands used
mutt=/usr/bin/mutt
AWSTOOL=/usr/local/bin/aws
TIMESTAMP=$( date )

echo "Would you like to create a (d)emo instance or (p)roduction instances?"
read use

if [ $use == "d" ];
  then
		# Create demo server for faculty

    # Set up the variables for creating a demo instance
    echo "Please enter the Discipline this course falls under i.e. INFS"
    read DISCIPLINE
    echo "Please enter the course number i.e. 6830"
    read COURSE_NUMBER
    echo "Please enter the section i.e. A"
    read COURSE_SECTION
    echo "Please enter the professor's last name i.e. laverty"
    read INSTRUCTOR
    echo "Please enter the term this course will occur in"
    read TERM
    echo "Please enter the location of the KeyFile"
    read KEYFILE

    # Create directory structure for logs
    mkdir /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM
    mkdir /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings
    mkdir /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles
    touch /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2RUNFILE.txt
    touch /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2TAGFILE.txt
		touch /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/AWS-Log.txt
    touch /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/err.log

    # Other important variables
    EC2RUNFILE=/root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2RUNFILE-$USER.txt
    EC2TAGFILE=/root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2TAGFILE.txt

    # Log errors to an error log
    exec 2>/root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/err.log

    # Create EC2 Instance
    echo "Creating Demo EC2 instance for $DISCIPLINE$COURSE_NUMBER$COURSE_SECTION"
    INSTANCE_ID=$($AWSTOOL ec2 run-instances --image-id ami-b57e31d0 --count 1 --instance-type t2.micro --key-name Acad_Master \
        --security-group-ids sg-dc094bbb --subnet-id subnet-634d0748 --query 'Instances[*].[InstanceId]' --output text)

    # Get Public Host Name from server
		echo "Waiting for EC2 Instance to begin"
		sleep 10
		STATUS=0
    while [status -ne 16]
    do
      STATUS=$($AWSTOOL ec2 describe-instance-status --query 'InstanceState[*].[Code]' --output text)
      echo "...still beginning"
      sleep 15
    done

    HOSTNAME=$($AWSTOOL ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].[PublicDnsName]' --output text)

    # Set Tags on instance
    echo "Creating tags on instance"
    $AWSTOOL ec2 create-tags --resources $INSTANCE_ID --tags Key=Name,Value=$TERM-$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION-$INSTRUCTOR.example.edu Key=Course,Value=$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION

    # Wait for SSH to be available befor continuing
		echo "Waiting for SSH to start..."
		sleep 30
		SSH_STATUS=255
    while [$SSH_STATUS -eq 255]
    do
			echo "...still waiting"
			sleep 15
      SSH_STATUS=$(ssh -o ConnectTimeout=4 $HOSTNAME)
    done

    #READ THE BELOW AND CORRECT

    # Add user groups to control permissions
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo groupadd students"
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo groupadd professors"
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo useradd -c \"$INSTRUCTOR\" -g professors -G students -s /bin/bash -m -d /home/$INSTRUCTOR $INSTRUCTOR"

    # Setup .ssh directories
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo mkdir /home/$INSTRUCTOR/.ssh"

    # Set ownership of the .ssh directores and set permissions
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo chown $INSTRUCTOR:professors /home/$INSTRUCTOR/.ssh"
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo chmod 700 /home/$INSTRUCTOR/.ssh"

    # Transfer the instructors key from EC2Box
    scp -o StrictHostKeyChecking=no -i $KEYFILE /root/keys/$INSTRUCTOR/$INSTRUCTOR.pem.pub ec2-user@$HOSTNAME:/home/ec2-user/$INSTRUCTOR.pem.pub

    # Copy the instructor key to the authorized_keys file
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo cp /home/ec2-user/$INSTRUCTOR.pem.pub /home/$INSTRUCTOR/.ssh/authorized_keys"

    # Change ownership of the authorized_keys files and set permissions
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo chown $INSTRUCTOR:professors /home/$INSTRUCTOR/.ssh/authorized_keys"
    ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ec2-user@$HOSTNAME "sudo chmod 600 /home/$INSTRUCTOR/.ssh/authorized_keys"

    # Create a local directory to store Key Backups
    mkdir /root/$DISCIPLINE$COURSE$SECTION$TERM/keys/$USER

		# Send email to faculty with login information
		# Variables for use in email
		MAILFILE=/root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings/$INSTRUCTOR.mail
		PUBLICKEY=$(cat /root/keys/$INSTRUCTOR/$INSTRUCTOR.pem.pub)
		NOTIFY=cos06@example.edu
		BLIND=cos06@example.edu
		ADMIN=cos06@example.edu
		SERVERS=$(ls /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings)
		REPORTFILE=/root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings/adminreport.mail

		touch /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings/$INSTRUCTOR.mail
		echo "Your demo account for $DISCIPLINE$COURSE_NUMBER-$COURSE_SECTION has been created.
		Hostname: $HOST
		Username: $INSTRUCTOR

		You can access the server via PuTTY on Windows or SSH on Mac.

		NOTE: You must use key-based authentication! You will find your private key attached.

		Your corresponding public key has been installed on the host already.
			Your Public Key is:
			$PUBLICKEY

		If you have any issues with this demo server, please contact the example Help Desk (help@example.edu)" >> $MAILFILE

		echo "     Sending mail to $NOTIFY..."
		$mutt -s "[$DISCIPLINE-$COURSE_NUMBER$COURSE_SECTION] Demo account setup information for $INSTRUCTOR" -b $BLIND -a /root/keys/$INSTRUCTOR/$INSTRUCTOR.pem -a /root/keys/$INSTRUCTOR/$INSTRUCTOR.ppk -a /root/attachments/UsingPuTTYtoLoginWindows.pdf -a /root/attachments/UsingsshtoLoginMac.pdf -a /root/attachments/SSHBuilder.zip -- $NOTIFY < $MAILFILE

		#Log email being sent
		echo "$TIMESTAMP:Sent email to $INSTRUCTOR with Private key and instructions to login" >> /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/AWS-Log.txt

		IFS=$OLDIFS

		touch /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings/adminreport.mail
		echo " The following emails were sent to Students:
			$SERVERS" >> $REPORTFILE

			$mutt -s "[$DISCIPLINE-$COURSE_NUMBER$COURSE_SECTION] EC2 Instance Creation Report" -a /root/demo/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/AWS-Log.txt -- $ADMIN < $REPORTFILE

    exit 0
  else
		# Create accounts for Students

		#Set up variables for creating the Student instances
		echo "Please enter the Discipline this course falls under i.e. INFS"
		read DISCIPLINE
		echo "Please enter the course number i.e. 6830"
		read COURSE_NUMBER
		echo "Please enter the section i.e. A"
		read COURSE_SECTION
		echo "Please enter the professor's last name i.e. laverty"
		read INSTRUCTOR
		echo "Please enter the term this course will occur in"
		read TERM
		echo "Please enter the location of the KeyFile"
		read KEYFILE
		echo "Please enter the location of the NAMEFILE"
		read NAMEFILE
		echo "Please enter the date these instances should expire"
		read EXPIREDATE

		# Create directory structure for logs
    mkdir /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM
    mkdir /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/mailings
    mkdir /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles
    touch /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2RUNFILE.txt
    touch /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2TAGFILE.txt
		touch /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/AWS-Log.txt
    touch /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/err.log

    # Other important variables
    EC2RUNFILE=/root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2RUNFILE-$USER.txt
    EC2TAGFILE=/root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/EC2TAGFILE.txt

    # Log errors to an error log
    exec 2> /root/$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION$TERM/runfiles/err.log

		while read USER STUDENT STID NUM
		do
			# Create EC2 Instance
	    echo "Creating Demo EC2 instance for $STUDENT"
	    INSTANCE_ID=$($AWSTOOL ec2 run-instances --image-id ami-b57e31d0 --count 1 --instance-type t2.micro --key-name Acad_Master \
	        --security-group-ids sg-dc094bbb --subnet-id subnet-634d0748 --query 'Instances[*].[InstanceId]' --output text)

	    # Get Public Host Name from server
			echo "Waiting for EC2 Instance to begin"
			sleep 10
			STATUS=0
	    while [status -ne 16]
	    do
	      STATUS=$($AWSTOOL ec2 describe-instance-status --query 'InstanceState[*].[Code]' --output text)
	      echo "...still beginning"
	      sleep 15
	    done

	    HOSTNAME=$($AWSTOOL ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[*].Instances[*].[PublicDnsName]' --output text)

	    # Set Tags on instance
	    echo "Creating tags on instance"
	    $AWSTOOL ec2 create-tags --resources $INSTANCE_ID --tags Key=NAME,Value=$TERM-$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION-$STUDENT.example.edu Key=COURSE,Value=$DISCIPLINE$COURSE_NUMBER$COURSE_SECTION KEY=Student,Value=$STUDENT Key=Expire,Value=$EXPIREDATE

	    # Wait for SSH to be available befor continuing
			echo "Waiting for SSH to start..."
			sleep 30
			SSH_STATUS=255
	    while [$SSH_STATUS -eq 255]
	    do
				echo "...still waiting"
				sleep 15
	      SSH_STATUS=$(ssh -o ConnectTimeout=4 $HOSTNAME)
	    done

			echo "Changing hostname for $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu"
			ssh -n -t -t -o StrictHostKeyChecking=no ubuntu@$HOSTNAME -i $KEYFILE 'sudo sed -i '/HOSTNAME=/cHOSTNAME=$TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu' /etc/sysconfig/network" > /dev/null 2>&1'
			echo "$TIMESTAMP:Set Hostname for $HOSTNAME to $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
			echo "Creating user $USER for $TERM-$DISCIPLINE$COURSE-$SECTION-$USER.example.edu" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
			# Add user groups to control permissions
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo groupadd students"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo groupadd professors"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo useradd -c \"$STUDENT\" -g students -s /bin/bash -m -d /home/$USER $USER"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo useradd -c \"$INSTRUCTOR\" -g professors -G students -s /bin/bash -m -d /home/$INSTRUCTOR $INSTRUCTOR"
			# Create the Key Pair for the Student
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "ssh-keygen -q -b 2048 -t rsa -C "$USER" -N \"\" -f /home/ubuntu/$USER.pem"
			# Setup .ssh directories
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo mkdir /home/$USER/.ssh"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo mkdir /home/$INSTRUCTOR/.ssh"
			# Set ownership of the .ssh directores and set permissions
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chown $USER:students /home/$USER/.ssh"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chown $INSTRUCTOR:professors /home/$INSTRUCTOR/.ssh"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chmod 700 /home/$USER/.ssh"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chmod 700 /home/$INSTRUCTOR/.ssh"
			# Copy the new private key to the student .ssh directory
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo cp /home/ubuntu/$USER.pem.pub /home/$USER/.ssh/authorized_keys"
			# Transfer the instructors key from EC2Box
			scp -o StrictHostKeyChecking=no -i $KEYFILE /root/keys/$INSTRUCTOR/$INSTRUCTOR.pem.pub ubuntu@$HOST:/home/ubuntu/$INSTRUCTOR.pem.pub
			# Copy the instructor key to the authorized_keys file
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo cp /home/ubuntu/$INSTRUCTOR.pem.pub /home/$INSTRUCTOR/.ssh/authorized_keys"
			# Change ownership of the authorized_keys files and set permissions
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chown $USER:students /home/$USER/.ssh/authorized_keys"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chown $INSTRUCTOR:professors /home/$INSTRUCTOR/.ssh/authorized_keys"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chmod 600 /home/$USER/.ssh/authorized_keys"
			ssh -n -t -t -o StrictHostKeyChecking=no -i $KEYFILE ubuntu@$HOSTNAME "sudo chmod 600 /home/$INSTRUCTOR/.ssh/authorized_keys"

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

		done < $NAMEFILE

		echo "     Done."
		echo ""
		echo "Done."
		echo ""

		echo "$TIMESTAMP:Script ended successfully, sending log to $ADMIN" >> /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt
		echo "		Sending script log..."

		touch /root/$DISCIPLINE$COURSE$SECTION$TERM/mailings/adminreport.mail
		echo " The following emails were sent to Students:
			$SERVERS" >> $REPORTFILE

			$mutt -s "[$DISCIPLINE-$COURSE$SECTION] EC2 Instance Creation Report" -a /root/$DISCIPLINE$COURSE$SECTION$TERM/runfiles/AWS-Log.txt -- $ADMIN < $REPORTFILE
		echo "Done."

    exit 0
fi
