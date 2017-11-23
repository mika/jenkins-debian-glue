#!/bin/bash

start_seconds=$(sed -e 's/^\([0-9]*\).*/\1/' < /proc/uptime)
[ -n "$start_seconds" ] && SECONDS="$[$(sed -e 's/^\([0-9]*\).*/\1/' < /proc/uptime)-$start_seconds]" || SECONDS="unknown"

if [ -r /var/lib/jenkins/config.xml ] ; then
  echo "Configuration file /var/lib/jenkins/config.xml exists already." >&2
  echo "Exiting to avoid possible data loss." >&2
  exit 1
fi

if [ $# -lt 1 ] ; then
  echo "Usage: $0 <password> [<http://path/to/some/puppetfile.pp>]" >&2
  exit 1
fi

SEED=$(head -c 12 /dev/urandom | base64)

if [ -z "$SEED" ] ; then
  echo "Error calculating seed. :(" >&2
  exit 1
fi

PASSWORD_HASH=$(echo -n "${1}"{"${SEED}"} | sha256sum | awk '{print $1}')

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
    wget -O jenkins_debian_glue.pp "$2"
  fi
else
  if ! [ -r jenkins_debian_glue.pp ] ; then
    wget https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp
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
  sed -i "s;PASSWORD_HASH_TO_BE_ADJUSTED;$PASSWORD_HASH;" jenkins_debian_glue.pp || exit 1
  sed -i "s;SEED_TO_BE_ADJUSTED;$SEED;" jenkins_debian_glue.pp || exit 1
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
# 'facter ec2_public_ipv4' returns nothing on Debian's AMI :(
if [ -z "$IP" ] ; then
  IP=$(wget --quiet --tries=3 --timeout=3 -O - http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
fi

# try Google Compute Engine
if [ -z "$IP" ] ; then
  IP=$(wget --quiet --tries=3 --timeout=3 -O - "http://metadata/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" --header "X-Google-Metadata-Request: True" 2>/dev/null)
fi

# neither using EC2 nor GCE? use a fallback then
if [ -z "$IP" ] ; then
  IP=$(ip addr show dev $(route -n | awk '/^0\.0\.0\.0/{print $NF}') | awk '/inet / {print $2}' | head -1 |sed "s;/.*;;")
fi

if [[ "$(hostname -f 2>/dev/null)" == "" ]] ; then
  echo "Error: please make sure you have a valid FQDN configured in /etc/hosts" >&2
  echo "NOTE:  Something like adding the following snippet to /etc/hosts might help:

$IP $(hostname).example.org $(hostname)
"
  exit 1
fi

if dpkg --compare-versions "$(dpkg-query -f "\${Version}\n" -W dpkg 2>/dev/null)" ge '1.17.11' 2>/dev/null ; then
  package_check() {
    [ "$(dpkg-query -f "\${db:Status-Status} \${db:Status-Eflag}" -W "$package" 2>/dev/null)" = 'installed ok' ]
  }
else # dpkg versions older than 1.17.11 (e.g. Debian/wheezy) don't support db:Status* flags, so fall back then
  package_check() {
    dpkg --list "$package" 2>/dev/null | grep -q '^.i'
  }
fi

package_installed() {
  local packages="$*"

  for package in $packages ; do
    if ! package_check "$package" ; then
      return 1
    fi
  done
}

if puppet apply jenkins_debian_glue.pp ; then
  if ! package_installed jenkins jenkins-debian-glue; then
    echo "While puppet reported a successful run, jenkins and/or jenkins-debian-glue aren't successfully installed. :(" >&2
    echo "Please re-execute this script and if the problem persists please report this at" >&2
    echo "https://github.com/mika/jenkins-debian-glue/issues" >&2
    exit 1
  fi

  [ -n "$start_seconds" ] && SECONDS="$[$(sed -e 's/^\([0-9]*\).*/\1/' < /proc/uptime)-$start_seconds]" || SECONDS="unknown"
  echo "jenkins-debian-glue deployment finished after ${SECONDS} seconds."
else
  echo "Fatal error during puppet run. :(" >&2
  exit 1
fi

echo "
NOTE: if you should notice failing Jenkins jobs this might be related to
incomplete Jenkins plugin dependencies (see
https://github.com/jenkinsci/puppet-jenkins/issues/64 +
https://github.com/jenkinsci/puppet-jenkins/issues/12 for details why we
can't easily automate that yet).

Usually this is related to the Git plugin. You can check whether the
Git plugin for Jenkins is installed by checking if the following URL
displays '<installed/>':

  http://${IP}:8080/updateCenter/plugin/git/api/xml?xpath=plugin/installed

If it returns something like 'XPath plugin/installed didn't match' then
please install the plugin by visiting:

  http://${IP}:8080/pluginManager/install?plugin.git.default

and then click on the 'Restart Jenkins' option there.

If the Git plugin is missing a dependency please report this at
https://github.com/mika/jenkins-debian-glue/issues

Enjoy your jenkins-debian-glue system!

Now point your browser to http://${IP}:8080"
