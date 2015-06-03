# jenkins::plugin::install is based on rtyler's
# https://github.com/jenkinsci/puppet-jenkins/blob/master/manifests/plugin.pp
define jenkins::plugin::install($version=0, $force=0) {
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

  if ($force != 0) {
    exec { "download-${name}" :
      command => "touch $plugin_dir/${name}.jpi.pinned; wget --no-check-certificate -O $plugin_dir/${name}.jpi ${base_url}${plugin}",
      cwd     => $plugin_dir,
      require => File[$plugin_dir],
      path    => ['/usr/bin', '/usr/sbin',],
      user    => 'jenkins',
      notify  => Service['jenkins'],
    }
  } else {
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

if $ec2_public_ipv4 {
  $jenkins_server = "$ec2_public_ipv4"
} elsif $ipaddress {
  $jenkins_server = "$ipaddress"
} else {
  $jenkins_server = "YOUR_JENKINS_SERVER"
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

  jenkins::plugin::install { 'copyartifact':
    require => Package['jenkins'],
  }

  # required for recent versions of ssh-agent
  jenkins::plugin::install { 'credentials':
    force   => '1', # see https://issues.jenkins-ci.org/browse/JENKINS-19927
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'git-client':
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'git':
    require => Package['jenkins'],
  }

  # required for recent versions of git
  jenkins::plugin::install { 'scm-api':
    require => Package['jenkins'],
  }

  # required for recent versions of git-client
  jenkins::plugin::install { 'ssh-agent':
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'tap':
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'timestamper':
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'ws-cleanup':
    require => Package['jenkins'],
  }

  package { 'default-jre-headless':
    ensure  => present,
  }

  # fix java headless issue, might also require
  #  sudo java -jar /usr/lib/jvm/java-6-openjdk-common/jre/lib/compilefontconfig.jar \
  #    /etc/java-6-openjdk/fontconfig.properties \
  #    /usr/lib/jvm/java-6-openjdk-common/jre/lib/fontconfig.bfc
  package { 'ttf-dejavu':
    ensure  => present,
  }

  package { 'jenkins':
    ensure  => present,
    require => [
      File['/etc/apt/sources.list.d/jenkins.list'],
      File['/etc/sudoers.d/jenkins'],
      Exec['refresh-apt-jenkins'],
      Package['default-jre-headless'],
    ]
  }

  package { [ 'jenkins-debian-glue',
            'jenkins-debian-glue-buildenv-git',
            'jenkins-debian-glue-buildenv-lintian',
            'jenkins-debian-glue-buildenv-svn',
            'jenkins-debian-glue-buildenv-taptools',
            'jenkins-debian-glue-buildenv-piuparts' ]:
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
    content => '## Deployed via jenkins_debian_glue.pp

# Make sure DEB_* options reach cowbuilder, like e.g.:
#  export DEB_BUILD_OPTIONS="parallel=8" /usr/bin/build-and-provide-package
Defaults  env_keep+="DEB_* DIST ARCH ADT"

# for *-binaries job
jenkins ALL=NOPASSWD: /usr/sbin/cowbuilder, /usr/sbin/chroot
# for *-piuparts job
jenkins ALL=NOPASSWD: /usr/sbin/piuparts, /usr/sbin/debootstrap, /usr/bin/piuparts_wrapper
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
  <description>Build Debian source package of jenkins-debian-glue</description>
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
        <name>master</name>
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
    <hudson.tasks.Shell>
      <command>mkdir -p report
/usr/bin/lintian-junit-report *.dsc &gt; report/lintian.xml</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>*.gz,*.bz2,*.xz,*.deb,*.dsc,*.git,*.changes,lintian.txt</artifacts>
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
    <hudson.tasks.junit.JUnitResultArchiver>
      <testResults>**/lintian.xml</testResults>
      <keepLongStdio>false</keepLongStdio>
      <testDataPublishers/>
    </hudson.tasks.junit.JUnitResultArchiver>
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
  <description>&lt;p&gt;Build Debian binary packages of jenkins-debian-glue&lt;/p&gt;&#xd;
&#xd;
&lt;h2&gt;Usage instructions how to remotely access and use the repository&lt;/h2&gt;&#xd;
&#xd;
&lt;p&gt;Install apache webserver:&lt;/p&gt;&#xd;
&#xd;
&lt;pre&gt;&#xd;
  sudo apt-get install apache2&#xd;
  sudo ln -s /srv/repository /var/www/debian&#xd;
&lt;/pre&gt;&#xd;
&#xd;
&lt;p&gt;Then access to this repository is available using the following sources.list entry:&lt;/p&gt;&#xd;
&#xd;
&lt;pre&gt;&#xd;
  deb     http://${jenkins_server}/debian/ jenkins-debian-glue main&#xd;
  deb-src http://${jenkins_server}/debian/ jenkins-debian-glue main&#xd;
&lt;/pre&gt;</description>
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
      <command>export POST_BUILD_HOOK=/usr/bin/jdg-debc
/usr/bin/build-and-provide-package</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>echo &quot;Listing packages inside the jenkins-debian-glue repository:&quot;
/usr/bin/repository_checker --list-repos jenkins-debian-glue</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>mkdir -p report
/usr/bin/lintian-junit-report *.dsc &gt; report/lintian.xml</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>*.gz,*.bz2,*.xz,*.deb,*.dsc,*.git,*.changes,lintian.txt</artifacts>
      <latestOnly>false</latestOnly>
    </hudson.tasks.ArtifactArchiver>
    <hudson.tasks.Fingerprinter>
      <targets></targets>
      <recordBuildArtifacts>true</recordBuildArtifacts>
    </hudson.tasks.Fingerprinter>
    <hudson.tasks.junit.JUnitResultArchiver>
      <testResults>**/lintian.xml</testResults>
      <keepLongStdio>false</keepLongStdio>
      <testDataPublishers/>
    </hudson.tasks.junit.JUnitResultArchiver>
    <hudson.tasks.BuildTrigger>
      <childProjects>jenkins-debian-glue-piuparts</childProjects>
      <threshold>
        <name>SUCCESS</name>
        <ordinal>0</ordinal>
        <color>BLUE</color>
      </threshold>
    </hudson.tasks.BuildTrigger>
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

  file { '/var/lib/jenkins/jobs/jenkins-debian-glue-piuparts/':
    ensure  => directory,
    mode    => '0755',
    owner   => 'jenkins',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/jobs/jenkins-debian-glue-piuparts/config.xml':
    ensure  => present,
    mode    => '0644',
    owner   => 'jenkins',
    require => File['/var/lib/jenkins/jobs/jenkins-debian-glue-piuparts'],
    notify  => Service['jenkins'],
    content => "<?xml version='1.0' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Installation and upgrade tests for jenkins-debian-glue Debian packages</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.StringParameterDefinition>
          <name>architecture</name>
          <description></description>
          <defaultValue>$::architecture</defaultValue>
        </hudson.model.StringParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <scm class='hudson.scm.NullSCM'/>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers class='vector'/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.plugins.copyartifact.CopyArtifact>
      <project>jenkins-debian-glue-binaries/architecture=\$architecture</project>
      <filter>*.deb</filter>
      <target>artifacts/</target>
      <selector class='hudson.plugins.copyartifact.TriggeredBuildSelector'>
        <fallbackToLastSuccessful>true</fallbackToLastSuccessful>
      </selector>
      <flatten>true</flatten>
    </hudson.plugins.copyartifact.CopyArtifact>
    <hudson.tasks.Shell>
      <command># sadly piuparts always returns with exit code 1 :((
sudo piuparts_wrapper \${PWD}/artifacts/*.deb || true</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>piuparts_tap piuparts.txt &gt; piuparts.tap</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <org.tap4j.plugin.TapPublisher>
      <testResults>piuparts.tap</testResults>
      <failIfNoResults>false</failIfNoResults>
      <failedTestsMarkBuildAsFailure>false</failedTestsMarkBuildAsFailure>
      <outputTapToConsole>false</outputTapToConsole>
      <enableSubtests>true</enableSubtests>
      <discardOldReports>false</discardOldReports>
      <todoIsFailure>false</todoIsFailure>
    </org.tap4j.plugin.TapPublisher>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>piuparts.*</artifacts>
      <latestOnly>false</latestOnly>
      <allowEmptyArchive>false</allowEmptyArchive>
    </hudson.tasks.ArtifactArchiver>
  </publishers>
  <buildWrappers>
    <hudson.plugins.ws__cleanup.PreBuildCleanup>
      <deleteDirs>false</deleteDirs>
    </hudson.plugins.ws__cleanup.PreBuildCleanup>
  </buildWrappers>
</project>
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
  <markupFormatter class='hudson.markup.RawHtmlMarkupFormatter' plugin='antisamy-markup-formatter@1.0'>
    <disableSyntaxHighlighting>false</disableSyntaxHighlighting>
  </markupFormatter>
  <views>
    <hudson.model.AllView>
      <owner class='hudson' reference='../../..'/>
      <name>All</name>
      <description>&lt;h1&gt;&lt;a href=&quot;http://jenkins-debian-glue.org/&quot;&gt;jenkins-debian-glue&lt;/a&gt; Continuous Integration labs&lt;/h1&gt;</description>
      <filterQueue>false</filterQueue>
      <properties class='hudson.model.View$PropertyList'/>
    </hudson.model.AllView>
  </views>
  <primaryView>All</primaryView>
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

  # SEED_TO_BE_ADJUSTED and PASSWORD_HASH will be adjusted by jenkins-debian-glue's apply.sh script
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
      <passwordHash>SEED_TO_BE_ADJUSTED:PASSWORD_HASH_TO_BE_ADJUSTED</passwordHash>
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
