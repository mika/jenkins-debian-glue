#!/bin/bash

date

if ! [ -r jenkins_debian_glue.pp ] ; then
  # support executing custom jenkins_debian_glue.pp
  if [ -n "$1" ] ; then
    wget -O jenkins_debian_glue.pp --no-check-certificate "$1"
  else
    wget --no-check-certificate https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp
  fi
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

# you have seen nothing, move along :)
GW_IP=$(ip addr show dev $(route -n | awk '/^0\.0\.0\.0/{print $NF}') | awk '/inet / {print $2}' | head -1 |sed "s;/.*;;")

if [[ $(facter fqdn) == "" ]] ; then
  echo "Error: please make sure you have a valid FQDN configured in /etc/hosts" >&2
  echo "NOTE:  Something like adding the following snippet to /etc/hosts might help:

$GW_IP $(hostname).example.org $(hostname)
"
  exit 1
fi

if puppet apply jenkins_debian_glue.pp ; then
  echo "jenkins-debian-glue deployment finished. \o/"
else
  echo "Fatal error during puppet run. :(" >&2
  exit 1
fi

date

echo "Now point your browser to http://${GW_IP}:8080"
