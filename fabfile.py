################################################################################
# Deploy Debian package to jenkins build system(s)
#
# Usage examples:
# % fab all
# % fab build && fab deploy
# % fab -H root@jenkins.example.org deploy
################################################################################

from fabric.api import *
import os, paramiko, sys

def set_hosts():
    if not env.hosts:
        env.hosts = []

        for host in 'jenkins', 'jenkins-slave1', 'jenkins-slave2', 'jenkins-slave3', 'jenkins-slave4', 'jenkins-slave5', 'jenkins-slave6':
            config = paramiko.SSHConfig()
            config.parse(open(os.path.expandvars("$HOME") + '/.ssh/config'))
            h = config.lookup(host)
            env.hosts.append(h['user'] + "@" + h['hostname'])

    return env.hosts

@runs_once
def build():
    local('rm -f ../jenkins-debian-glue*all.deb')
    local('fakeroot debian/rules clean')
    local('fakeroot debian/rules binary')
    local('fakeroot debian/rules clean')

@hosts(set_hosts())
def deploy():
    put('../jenkins-debian-glue*_all.deb', '~/')
    run('dpkg -i ~/jenkins-debian-glue*_all.deb || apt-get -f install')

def all():
    build()
    deploy()

## END OF FILE #################################################################
