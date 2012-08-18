#!/bin/bash

start_seconds=$(cut -d . -f 1 /proc/uptime)
[ -n "$start_seconds" ] && SECONDS="$[$(cut -d . -f 1 /proc/uptime)-$start_seconds]" || SECONDS="unknown"

if [ -r /var/lib/jenkins/config.xml ] ; then
  echo "Configuration file /var/lib/jenkins/config.xml exists already." >&2
  echo "Exiting to avoid possible data loss." >&2
  exit 1
fi

if [ $# -lt 1 ] ; then
  echo "Usage: $0 <password> [<http://path/to/some/puppetfile.pp>]" >&2
  exit 1
fi

PASSWORD_HASH=$(echo -n "${1}{jenkins-debian-glue}" | sha256sum | awk '{print $1}')

if [ -z "$PASSWORD_HASH" ] ; then
  echo "Error calculating password hash. :(" >&2
  exit 1
fi

if [ -n "$2" ] ; then
  if [ -r jenkins_debian_glue.pp ] ; then
    echo "Error: file jenkins_debian_glue.pp exists already. Exiting to avoid possible data loss." >&2
    exit 1
  else
    echo "Retrieving $2 and storing as jenkins_debian_glue.pp"
    wget -O jenkins_debian_glue.pp --no-check-certificate "$2"
  fi
else
  if ! [ -r jenkins_debian_glue.pp ] ; then
    wget --no-check-certificate https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp
  fi
fi

if ! grep -q PASSWORD_HASH_TO_BE_ADJUSTED jenkins_debian_glue.pp ; then
  echo "################################################################################"
  echo "Warning: string PASSWORD_HASH_TO_BE_ADJUSTED not found in jenkins_debian_glue.pp"
  echo "Notice that rerunning $0 with a different password might not work as expected."
  echo "To make sure adjusting the password works please execute:

  rm jenkins_debian_glue.pp
  $0 <your_password> https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp"
  echo
  echo "################################################################################"
else
  printf "Adjusting password in jenkins_debian_glue.pp: "
  sed -i "s/PASSWORD_HASH_TO_BE_ADJUSTED/$PASSWORD_HASH/" jenkins_debian_glue.pp || exit 1
  echo OK
fi

if ! [ -r jenkins_debian_glue.pp ] ; then
  echo "Error: can not find jenkins_debian_glue.pp." >&2
  echo "Either manually grab https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp" >&2
  echo "       or run $0 <http://path/to/some/puppetfile.pp>" >&2
  exit 1
fi

if ! type puppet &>/dev/null ; then
  apt-get update
  apt-get -y install puppet || exit 1
fi

# Amazon EC2 returns the internal IP by default, so ask about the public one
IP=$(facter ec2_public_ipv4 2>/dev/null) # curl http://169.254.169.254/latest/meta-data/public-ipv4
if [ -z "$IP" ] ; then
  IP=$(ip addr show dev $(route -n | awk '/^0\.0\.0\.0/{print $NF}') | awk '/inet / {print $2}' | head -1 |sed "s;/.*;;")
fi

if [[ $(facter fqdn) == "" ]] ; then
  echo "Error: please make sure you have a valid FQDN configured in /etc/hosts" >&2
  echo "NOTE:  Something like adding the following snippet to /etc/hosts might help:

$IP $(hostname).example.org $(hostname)
"
  exit 1
fi

if puppet apply jenkins_debian_glue.pp ; then
  [ -n "$start_seconds" ] && SECONDS="$[$(cut -d . -f 1 /proc/uptime)-$start_seconds]" || SECONDS="unknown"
  echo "jenkins-debian-glue deployment finished after ${SECONDS} seconds."
else
  echo "Fatal error during puppet run. :(" >&2
  exit 1
fi


echo "Now point your browser to http://${IP}:8080"
