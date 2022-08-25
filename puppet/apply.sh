#!/bin/bash

start_seconds=$(sed -e 's/^\([0-9]*\).*/\1/' < /proc/uptime)
[ -n "$start_seconds" ] && SECONDS="$[$(sed -e 's/^\([0-9]*\).*/\1/' < /proc/uptime)-$start_seconds]" || SECONDS="unknown"

if [ -r /var/lib/jenkins/config.xml ] ; then
  echo "NOTE: Configuration file /var/lib/jenkins/config.xml exists already."

  if [ "$1" == "--force" ] ; then
    echo "Continuing execution as requested via --force."
  else
    echo "Exiting to avoid possible data loss. To force execution, run '$0 --force'" >&2
    exit 1
  fi
fi

# workaround for puppet's facter, which looks at `uname -m` (reporting e.g. aarch64)
# while `dpkg --print-architecture` reports arm64
export FACTER_JDG_DEBIAN_ARCH="$(dpkg --print-architecture)"

if [ -z "${FACTER_JDG_DEBIAN_ARCH:-}" ] ; then
  echo "Error reporting Debian architecture (via 'dpkg --print-architecture')" >&2
  exit 1
fi

if ! [ -r jenkins_debian_glue.pp ] ; then
  wget https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp
fi

if ! [ -r jenkins_debian_glue.pp ] ; then
  echo "Error: can not find jenkins_debian_glue.pp." >&2
  echo "Make sure to fetch e.g. https://raw.github.com/mika/jenkins-debian-glue/master/puppet/jenkins_debian_glue.pp" >&2
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
    local package="$1"
    [ "$(dpkg-query -f "\${db:Status-Status} \${db:Status-Eflag}" -W "$package" 2>/dev/null)" = 'installed ok' ]
  }
else # dpkg versions older than 1.17.11 (e.g. Debian/wheezy) don't support db:Status* flags, so fall back then
  package_check() {
    local package="$1"
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
