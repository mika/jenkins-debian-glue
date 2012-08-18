# jenkins::plugin::install is based on rtyler's
# https://github.com/rtyler/puppet-jenkins/blob/master/manifests/plugin/install.pp
define jenkins::plugin::install($version=0) {
  $plugin = "${name}.hpi"
  $plugin_parent_dir = '/var/lib/jenkins'
  $plugin_dir = '/var/lib/jenkins/plugins'

  if ($version != 0) {
    $base_url = "http://updates.jenkins-ci.org/download/plugins/${name}/${version}/"
  }
  else {
    $base_url = 'http://updates.jenkins-ci.org/latest/'
  }

  if (!defined(File[$plugin_dir])) {
    file {
      [$plugin_parent_dir, $plugin_dir]:
        ensure => directory,
        owner  => 'jenkins',
    }
  }

  exec { "download-${name}" :
    command => "wget --no-check-certificate ${base_url}${plugin}",
    cwd     => $plugin_dir,
    require => File[$plugin_dir],
    path    => ['/usr/bin', '/usr/sbin',],
    user    => 'jenkins',
    unless  => "test -f ${plugin_dir}/${plugin}",
    notify  => Service['jenkins'],
  }
}

exec { 'apt-get_update':
  refreshonly => true,
  path        => '/bin:/usr/bin',
  command     => 'apt-get update',
}

define apt::key($ensure = present, $source) {
  case $ensure {
    present: {
      exec { "/usr/bin/wget -O - '$source' | /usr/bin/apt-key add -":
        unless => "apt-key list | grep -Fqe '${name}'",
        path   => '/bin:/usr/bin',
        before => Exec['apt-get_update'],
        notify => Exec['apt-get_update'],
      }
    }

    absent: {
      exec {"/usr/bin/apt-key del ${name}":
        onlyif => "apt-key list | grep -Fqe '${name}'",
      }
    }
  }
}

class jenkins::repos {

  apt::key { 'D50582E6':
    ensure => present,
    source => 'http://pkg.jenkins-ci.org/debian-stable/jenkins-ci.org.key',
  }

  file { '/etc/apt/sources.list.d/jenkins.list':
    ensure  => present,
    notify  => Exec['refresh-apt-jenkins'],
    content => 'deb http://pkg.jenkins-ci.org/debian-stable binary/',
    require => Apt::Key['D50582E6'],
  }

  exec { 'refresh-apt-jenkins':
    refreshonly => true,
    require     => [
      File['/etc/apt/sources.list.d/jenkins.list'],
      Apt::Key['D50582E6'],
    ],
    path        => ['/usr/bin', '/usr/sbin'],
    command     => 'apt-get update',
  }

  apt::key { '52D4A654':
    ensure => present,
    source => 'http://jenkins.grml.org/debian/C525F56752D4A654.asc',
  }

  file { '/etc/apt/sources.list.d/jenkins-debian-glue.list':
    ensure  => present,
    notify  => Exec['refresh-apt-jenkins-debian-glue'],
    content => 'deb http://jenkins.grml.org/debian jenkins-debian-glue main',
    require => Apt::Key['52D4A654'],
  }

  exec { 'refresh-apt-jenkins-debian-glue':
    refreshonly => true,
    require     => [
      File['/etc/apt/sources.list.d/jenkins-debian-glue.list'],
      Apt::Key['52D4A654'],
    ],
    path        => ['/usr/bin', '/usr/sbin'],
    command     => 'apt-get update';
  }
}


class jenkins::software {

  jenkins::plugin::install { 'git':
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'copyartifact':
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'ws-cleanup':
    require => Package['jenkins'],
  }

  package { 'jenkins':
    ensure  => present,
    require => [
      File['/etc/apt/sources.list.d/jenkins.list'],
      File['/etc/sudoers.d/jenkins'],
      Exec['refresh-apt-jenkins'],
    ]
  }

  package { [ 'jenkins-debian-glue',
            'jenkins-debian-glue-buildenv-git',
            'jenkins-debian-glue-buildenv-lintian',
            'jenkins-debian-glue-buildenv-svn' ]:
    ensure  => present,
    require => [
      File['/etc/apt/sources.list.d/jenkins-debian-glue.list'],
      Exec['refresh-apt-jenkins-debian-glue'],
    ]
  }

  service { 'jenkins':
    ensure  => running,
    require => Package['jenkins'],
  }

  package { 'sudo':
    ensure => present,
  }

  file { '/etc/sudoers.d/jenkins':
    mode    => '0440',
    content => 'jenkins ALL=NOPASSWD: /usr/sbin/cowbuilder, /usr/sbin/chroot
',
    require => Package['sudo'],
  }
}


class jenkins::reprepro {
  file { '/srv/repository':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => Package['jenkins'],
  }
}


class jenkins::config {
  file { '/var/lib/jenkins/.gitconfig':
    ensure  => present,
    mode    => '0644',
    owner   => 'jenkins',
    content =>'[user]
        email = jenkins@example.org
        name = Jenkins User
',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/jobs':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/jobs/jenkins-debian-glue-source':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/jobs/jenkins-debian-glue-source/config.xml':
    ensure  => present,
    mode    => '0644',
    owner   => 'jenkins',
    require => File['/var/lib/jenkins/jobs/jenkins-debian-glue-source'],
    notify  => Service['jenkins'],
    content => "<?xml version='1.0' encoding='UTF-8'?>
<project>
  <actions/>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class='hudson.plugins.git.GitSCM'>
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <name></name>
        <refspec></refspec>
        <url>git://github.com/mika/jenkins-debian-glue.git</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>**</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <disableSubmodules>false</disableSubmodules>
    <recursiveSubmodules>false</recursiveSubmodules>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <authorOrCommitter>false</authorOrCommitter>
    <clean>false</clean>
    <wipeOutWorkspace>false</wipeOutWorkspace>
    <pruneBranches>false</pruneBranches>
    <remotePoll>false</remotePoll>
    <ignoreNotifyCommit>false</ignoreNotifyCommit>
    <buildChooser class='hudson.plugins.git.util.DefaultBuildChooser'/>
    <gitTool>Default</gitTool>
    <submoduleCfg class='list'/>
    <relativeTargetDir>source</relativeTargetDir>
    <reference></reference>
    <excludedRegions></excludedRegions>
    <excludedUsers></excludedUsers>
    <gitConfigName></gitConfigName>
    <gitConfigEmail></gitConfigEmail>
    <skipTag>false</skipTag>
    <includedRegions></includedRegions>
    <scmName></scmName>
  </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers class='vector'/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>rm -f ./* || true</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command># when using git:
/usr/bin/generate-git-snapshot

# when using subversion:
# /usr/bin/generate-svn-snapshot</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>*.gz,*.bz2,*.xz,*.deb,*.dsc,*.changes</artifacts>
      <latestOnly>false</latestOnly>
    </hudson.tasks.ArtifactArchiver>
    <hudson.tasks.Fingerprinter>
      <targets></targets>
      <recordBuildArtifacts>true</recordBuildArtifacts>
    </hudson.tasks.Fingerprinter>
    <hudson.tasks.BuildTrigger>
      <childProjects>jenkins-debian-glue-binaries</childProjects>
      <threshold>
        <name>SUCCESS</name>
        <ordinal>0</ordinal>
        <color>BLUE</color>
      </threshold>
    </hudson.tasks.BuildTrigger>
  </publishers>
  <buildWrappers/>
</project>
"
  }

  file { '/var/lib/jenkins/jobs/jenkins-debian-glue-binaries':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/jobs/jenkins-debian-glue-binaries/config.xml':
    ensure  => present,
    mode    => '0644',
    owner   => 'jenkins',
    require => File['/var/lib/jenkins/jobs/jenkins-debian-glue-binaries'],
    notify  => Service['jenkins'],
    content => "<?xml version='1.0' encoding='UTF-8'?>
<matrix-project>
  <actions/>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class='hudson.scm.NullSCM'/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers class='vector'/>
  <concurrentBuild>false</concurrentBuild>
  <axes>
    <hudson.matrix.TextAxis>
      <name>architecture</name>
      <values>
        <string>$::architecture</string>
      </values>
    </hudson.matrix.TextAxis>
  </axes>
  <builders>
    <hudson.plugins.copyartifact.CopyArtifact>
      <projectName>jenkins-debian-glue-source</projectName>
      <filter>*</filter>
      <target></target>
      <selector class='hudson.plugins.copyartifact.TriggeredBuildSelector'>
        <fallbackToLastSuccessful>true</fallbackToLastSuccessful>
      </selector>
    </hudson.plugins.copyartifact.CopyArtifact>
    <hudson.tasks.Shell>
      <command>/usr/bin/build-and-provide-package</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>echo &quot;Listing packages inside the jenkins-debian-glue repository:&quot;
/usr/bin/repository_checker --list-repos jenkins-debian-glue</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>*.gz,*.bz2,*.xz,*.deb,*.dsc,*.changes</artifacts>
      <latestOnly>false</latestOnly>
    </hudson.tasks.ArtifactArchiver>
    <hudson.tasks.Fingerprinter>
      <targets></targets>
      <recordBuildArtifacts>true</recordBuildArtifacts>
    </hudson.tasks.Fingerprinter>
  </publishers>
  <buildWrappers>
    <hudson.plugins.ws__cleanup.PreBuildCleanup>
      <deleteDirs>false</deleteDirs>
    </hudson.plugins.ws__cleanup.PreBuildCleanup>
  </buildWrappers>
  <executionStrategy class='hudson.matrix.DefaultMatrixExecutionStrategyImpl'>
    <runSequentially>true</runSequentially>
  </executionStrategy>
</matrix-project>
"
  }

  file { '/var/lib/jenkins/config.xml':
    ensure  => present,
    mode    => '0644',
    owner   => 'jenkins',
    require => Package['jenkins'],
    notify  => Service['jenkins'],
    content => "<?xml version='1.0' encoding='UTF-8'?>
<hudson>
  <useSecurity>true</useSecurity>
  <authorizationStrategy class='hudson.security.FullControlOnceLoggedInAuthorizationStrategy'/>
  <securityRealm class='hudson.security.HudsonPrivateSecurityRealm'>
    <disableSignup>true</disableSignup>
    <enableCaptcha>false</enableCaptcha>
  </securityRealm>
  <systemMessage>&lt;h1&gt;&lt;a href=&quot;http://jenkins-debian-glue.org/&quot;&gt;jenkins-debian-glue&lt;/a&gt; Continuous Integration labs&lt;/h1&gt;</systemMessage>
</hudson>
"
  }

  file { '/var/lib/jenkins/users/':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/users/jenkins-debian-glue/':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => File['/var/lib/jenkins/users/'],
  }

  # PASSWORD_HASH will be adjusted by jenkins-debian-glue's apply.sh script
  file { '/var/lib/jenkins/users/jenkins-debian-glue/config.xml':
    ensure       => present,
    mode         => '0644',
    owner        => 'jenkins',
    require      => File['/var/lib/jenkins/users/jenkins-debian-glue/'],
    notify       => Service['jenkins'],
    content      => "<?xml version='1.0' encoding='UTF-8'?>
<user>
  <fullName>Jenkins Debian Glue</fullName>
  <properties>
    <jenkins.security.ApiTokenProperty>
      <apiToken>R5A9eoSreMtS3iYuvmCyrIJ1q3DQGGquBgkr7sJapuYNPLWvy5cfaT6EOAnb10kY</apiToken>
    </jenkins.security.ApiTokenProperty>
    <hudson.model.MyViewsProperty>
      <views>
        <hudson.model.AllView>
          <owner class='hudson.model.MyViewsProperty' reference='../../..'/>
          <name>All</name>
          <filterExecutors>false</filterExecutors>
          <filterQueue>false</filterQueue>
          <properties class='hudson.model.View$PropertyList'/>
        </hudson.model.AllView>
      </views>
    </hudson.model.MyViewsProperty>
    <hudson.search.UserSearchProperty>
      <insensitiveSearch>false</insensitiveSearch>
    </hudson.search.UserSearchProperty>
    <hudson.security.HudsonPrivateSecurityRealm_-Details>
      <passwordHash>jenkins-debian-glue:PASSWORD_HASH_TO_BE_ADJUSTED</passwordHash>
    </hudson.security.HudsonPrivateSecurityRealm_-Details>
    <hudson.tasks.Mailer_-UserProperty>
      <emailAddress>jenkins@example.org</emailAddress>
    </hudson.tasks.Mailer_-UserProperty>
  </properties>
</user>
"
  }
}

## software
include jenkins::repos
include jenkins::software
include jenkins::config
include jenkins::reprepro
