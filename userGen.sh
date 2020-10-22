#!/bin/bash

#const
GROUP_NAME="CSI-230"

usage()
{
  echo "$0 usage: [ -f inputfile ]"
  exit 1
}


#Brief: checks to make sure usre is root and exits the program if not
root_check()
{
   if [ "$(whoami)" != "root" ]; then
   echo "Sorry dude, root only"
   exit 1
   fi
}


send_email()
{
  #send email
    echo "To email you your new password you need to log in to a gmail account"

    read -p "Username: " gmailUname

    read -s -p "Password: " gmailPass

    make_new_config > tmp.txt

    make_email > tmp2.txt

    ssmtp -C tmp.txt ${uname}"@"${domain} < tmp2.txt
    echo "Email sent"
    rm tmp.txt
    rm tmp2.txt

}

make_new_config()
{
  echo "  #"
  echo "# Config file for sSMTP sendmail"
  echo "#"
  echo "# The person who gets all mail for userids < 1000"
  echo "# Make this empty to disable rewriting."
  echo "root=Pop_postmaster"
  echo "# The place where the mail goes. The actual machine name is required no"
  echo "# MX records are consulted. Commonly mailhosts are named mail.domain.com"
  echo "mailhub=smtp.gmail.com:587"
  echo "# Where will the mail seem to come from?"
  echo "#rewriteDomain=Pop_postmaster"
  echo "# The full hostname"
  echo "hostname=pop-os.localdomain"
  echo "# Are users allowed to set their own From: address?"
  echo "# YES - Allow the user to specify their own From: address"
  echo "# NO - Use the system generated From: address"
  echo "AuthUser=${gmailUname}"
  echo "AuthPass=${gmailPass}"
  echo "FromLineOverride=NO"
  echo "UseSTARTTLS=YES"
  echo "AuthMethod=LOGIN"

}


make_email()
{
  cat <<- _EOF_
	To: ${uname}@${domain}
	From: ${gmailUname}
	Subject: New Password
${pass}
_EOF_
}


#makes sure the correct options are passed in
while getopts ":f:" options;
do
    case ${options} in
      f)
        f=${OPTARG}
        if [[ -f ${f} && -e ${f} ]]; then
          echo "File ${f} found"
	  exec {file_descriptor}<${f}
        else
          usage
        fi
      ;;

      *)
          usage
      ;;
    esac
done


#main
root_check
groupExists=false
while read -u ${file_descriptor} -e line
do

#check for group and make if not exitst
  if ! ${groupExists}; then
    while read -d: groupLine
    do
      if [[ ${groupLine} = ${GROUP_NAME} ]]; then
        groupExists=true
      fi
    done < /etc/group
  fi

  if ${groupExists}; then
  #group exists
    echo "Group exists is ${groupExists}"
  else
  #make group
    groupadd ${GROUP_NAME}
    echo "Group does not exist"
    echo "..."
    echo "Group created"
    groupExists=true

  fi


  echo "Email grabbed: ${line}"


#split line at '@'
  domain=${line#*@}
  uname=${line%@*}
  echo "User name = ${uname}"
#  echo "Domain = ${domain}"

#generate password
  pass="$(openssl rand -base64 9)"
#  echo "${pass}"
  echo "Password = ************"

#check for user exist
  if id "$uname" &>/dev/null; then
    echo "User ${uname} exists"

  #add to CSI group
    usermod -a -G ${GROUP_NAME} ${uname}

  #update password
    echo "Updating ${uname} password to newly generated password"
    echo "${uname}:${pass}" | chpasswd

    chage -d 0 -M 0 ${uname}

  #send email
  send_email

  else
    echo "User does not exist"
    echo "Creating user ${uname}"

  #create user
    useradd -m ${uname}
    echo "${uname}:${pass}" | chpasswd

  #set new user shell to bash
    usermod -s /bin/bash ${uname}

  #make sure user has to change password when they log in
    chage -d 0 -M 0 ${uname}

  #add to CSI group
    usermod -a -G ${GROUP_NAME} ${uname}

  #send email
    send_email

  fi


done

exit 0
