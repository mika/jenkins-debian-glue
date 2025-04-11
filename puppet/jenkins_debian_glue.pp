# jenkins::plugin::install is based on rtyler's
# https://github.com/jenkinsci/puppet-jenkins/blob/master/manifests/plugin.pp
define jenkins::plugin::install($version=0, $force=0) {
  $plugin = "${name}.hpi"
  $plugin_parent_dir = '/var/lib/jenkins'
  $plugin_dir = '/var/lib/jenkins/plugins'

  if ($version != 0) {
    $base_url = "http://updates.jenkins.io/download/plugins/${name}/${version}/"
  }
  else {
    $base_url = 'http://updates.jenkins.io/latest/'
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
      command => "touch ${plugin_dir}/${name}.jpi.pinned; wget -O ${plugin_dir}/${name}.jpi ${base_url}${plugin}",
      cwd     => $plugin_dir,
      require => [File[$plugin_dir], Package['wget']],
      path    => ['/usr/bin', '/usr/sbin',],
      user    => 'jenkins',
      notify  => Service['jenkins'],
    }
  } else {
    exec { "download-${name}" :
      command => "wget ${base_url}${plugin}",
      cwd     => $plugin_dir,
      require => [File[$plugin_dir], Package['wget']],
      path    => ['/usr/bin', '/usr/sbin',],
      user    => 'jenkins',
      unless  => "test -f ${plugin_dir}/${plugin}",
      notify  => Service['jenkins'],
    }
  }

}

define apt::key($ensure = present, $source) {
  case $ensure {
    present: {
      exec { "/usr/bin/wget -O - '${source}' | /usr/bin/apt-key add -":
        unless  => "apt-key list | grep -Fqe '${name}'",
        path    => '/bin:/usr/bin',
        require => Package['wget'],
      }
    }

    absent: {
      exec {"/usr/bin/apt-key del ${name}":
        onlyif => "apt-key list | grep -Fqe '${name}'",
      }
    }
  }
}

if defined('$ec2_public_ipv4') {
  $jenkins_server = $ec2_public_ipv4
} elsif defined('$ipaddress') {
  $jenkins_server = $ipaddress
} else {
  $jenkins_server = 'YOUR_JENKINS_SERVER'
}

class jenkins::repos {

  package { 'apt-transport-https':
    ensure => present,
  }

  package { 'gnupg':
    ensure => present,
  }

  package { 'wget':
    ensure => present,
  }

  apt::key { 'EF5975CA':
    ensure => present,
    source => 'https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key',
  }

  file { '/etc/apt/sources.list.d/jenkins.list':
    ensure  => present,
    content => "deb https://pkg.jenkins.io/debian-stable binary/\n",
    require => [
      Apt::Key['EF5975CA'],
      Package['apt-transport-https'],
    ],
  }

  exec { 'refresh-apt-jenkins':
    require => [
      File['/etc/apt/sources.list.d/jenkins.list'],
      Apt::Key['EF5975CA'],
    ],
    command => '/usr/bin/apt-get update',
  }
}


class jenkins::software {

  # Make all jenkins::plugin::install items require Package['jenkins']:
  Jenkins::Plugin::Install {
    require => Package['jenkins'],
  }

  jenkins::plugin::install { 'copyartifact':
  }

  # required for recent versions of ssh-agent
  jenkins::plugin::install { 'credentials':
    force   => '1', # see https://issues.jenkins-ci.org/browse/JENKINS-19927
  }

  # required for recent versions of credentials
  jenkins::plugin::install { 'icon-shim':
  }

  # required for recent versions of credentials
  jenkins::plugin::install { 'ssh-credentials':
  }

  jenkins::plugin::install { 'git-client':
  }

  jenkins::plugin::install { 'git':
  }

  # required for recent versions of git
  jenkins::plugin::install { 'scm-api':
  }

  jenkins::plugin::install { 'matrix-project':
  }

  jenkins::plugin::install { 'junit':
    force => '1', # needed since 2.176.2, see https://issues.jenkins-ci.org/browse/JENKINS-57528
  }
  # dependencies for junit plugin
  jenkins::plugin::install { 'bootstrap4-api': }
  jenkins::plugin::install { 'plugin-util-api': }
  jenkins::plugin::install { 'echarts-api': }
  jenkins::plugin::install { 'jackson2-api': }
  jenkins::plugin::install { 'checks-api': }
  # dependency for Bootstrap 4 API + ECharts API plugins
  jenkins::plugin::install { 'jquery3-api': }
  # dependencies for Bootstrap 4 API Plugin
  jenkins::plugin::install { 'popper-api': }
  jenkins::plugin::install { 'font-awesome-api': }
  # dependency for Jackson 2 API Plugin
  jenkins::plugin::install { 'snakeyaml-api': }
  # dependency for Checks API plugin
  jenkins::plugin::install { 'workflow-cps': }
  # dependency for Groovy plugin (which is required by Checks API plugin)
  jenkins::plugin::install { 'ace-editor': }

  jenkins::plugin::install { 'script-security':
  }

  jenkins::plugin::install { 'workflow-scm-step':
  }

  jenkins::plugin::install { 'mailer':
  }

  jenkins::plugin::install { 'display-url-api':
  }

  # required for recent versions of git-client
  jenkins::plugin::install { 'ssh-agent':
  }

  # required for recent versions of Jenkins Git client plugin
  jenkins::plugin::install { 'apache-httpcomponents-client-4-api':
  }

  jenkins::plugin::install { 'jsch':
  }

  jenkins::plugin::install { 'trilead-api':
  }

  # required for recent versions of ssh-agent
  jenkins::plugin::install { 'workflow-step-api':
  }

  jenkins::plugin::install { 'bouncycastle-api':
    force => '1', # needed since 2.176.2, see https://issues.jenkins-ci.org/browse/JENKINS-57528
  }

  jenkins::plugin::install { 'structs':
  }

  jenkins::plugin::install { 'tap':
  }

  jenkins::plugin::install { 'timestamper':
  }

  jenkins::plugin::install { 'ws-cleanup':
  }

  # required for recent versions of ws-cleanup
  jenkins::plugin::install { 'workflow-durable-task-step':
  }

  jenkins::plugin::install { 'resource-disposer':
  }

  # note: workflow-aggregator is a dependency of ws-cleanup and
  # is the plugin ID for "Pipeline Plugin"
  jenkins::plugin::install { 'workflow-aggregator':
  }

  jenkins::plugin::install { 'pipeline-input-step':
  }
  jenkins::plugin::install { 'workflow-job':
  }
  jenkins::plugin::install { 'workflow-basic-steps':
  }
  jenkins::plugin::install { 'workflow-api':
  }
  jenkins::plugin::install { 'workflow-support':
  }
  jenkins::plugin::install { 'durable-task':
  }

  # required for usage of HTML markup in user-submitted text
  jenkins::plugin::install { 'antisamy-markup-formatter':
  }

  # indirectly dependent plugins as of Jenkins >=2.346.3 and plugins we depend on
  jenkins::plugin::install { 'bootstrap5-api':
  }
  jenkins::plugin::install { 'branch-api':
  }
  jenkins::plugin::install { 'build-timeout':
  }
  jenkins::plugin::install { 'caffeine-api':
  }
  jenkins::plugin::install { 'cloudbees-folder':
  }
  jenkins::plugin::install { 'command-launcher':
  }
  jenkins::plugin::install { 'commons-lang3-api':
  }
  jenkins::plugin::install { 'commons-text-api':
  }
  jenkins::plugin::install { 'credentials-binding':
  }
  jenkins::plugin::install { 'email-ext':
  }
  jenkins::plugin::install { 'github':
  }
  jenkins::plugin::install { 'github-api':
  }
  jenkins::plugin::install { 'github-branch-source':
  }
  jenkins::plugin::install { 'gradle':
  }
  jenkins::plugin::install { 'handlebars':
  }
  jenkins::plugin::install { 'ionicons-api':
  }
  jenkins::plugin::install { 'jakarta-activation-api':
  }
  jenkins::plugin::install { 'jakarta-mail-api':
  }
  jenkins::plugin::install { 'javax-activation-api':
  }
  jenkins::plugin::install { 'javax-mail-api':
  }
  jenkins::plugin::install { 'jaxb':
  }
  jenkins::plugin::install { 'jdk-tool':
  }
  jenkins::plugin::install { 'jjwt-api':
  }
  jenkins::plugin::install { 'ldap':
  }
  jenkins::plugin::install { 'matrix-auth':
  }
  jenkins::plugin::install { 'momentjs':
  }
  jenkins::plugin::install { 'okhttp-api':
  }
  jenkins::plugin::install { 'pam-auth':
  }
  jenkins::plugin::install { 'pipeline-build-step':
  }
  jenkins::plugin::install { 'pipeline-github-lib':
  }
  jenkins::plugin::install { 'pipeline-graph-analysis':
  }
  jenkins::plugin::install { 'pipeline-groovy-lib':
  }
  jenkins::plugin::install { 'pipeline-milestone-step':
  }
  jenkins::plugin::install { 'pipeline-model-api':
  }
  jenkins::plugin::install { 'pipeline-model-definition':
  }
  jenkins::plugin::install { 'pipeline-model-extensions':
  }
  jenkins::plugin::install { 'pipeline-rest-api':
  }
  jenkins::plugin::install { 'pipeline-stage-step':
  }
  jenkins::plugin::install { 'pipeline-stage-tags-metadata':
  }
  jenkins::plugin::install { 'pipeline-stage-view':
  }
  jenkins::plugin::install { 'plain-credentials':
  }
  jenkins::plugin::install { 'popper2-api':
  }
  jenkins::plugin::install { 'ssh-slaves':
  }
  jenkins::plugin::install { 'token-macro':
  }
  jenkins::plugin::install { 'variant':
  }
  jenkins::plugin::install { 'workflow-multibranch':
  }

  $java_package = $facts['os']['name'] ? {
    'Ubuntu' => $facts['os']['distro']['codename'] ? {
      # Using openjdk-8 for Ubuntu 18.01, as Jenkins stable does not support openjdk-11 yet.
      'bionic' => 'openjdk-8-jre-headless',
      default  => 'default-jre-headless',
    },
    default => 'default-jre-headless',
  }

  package { $java_package:
    ensure  => present,
  }

  package { 'jenkins':
    ensure  => present,
    require => [
      File['/etc/apt/sources.list.d/jenkins.list'],
      File['/etc/sudoers.d/jenkins'],
      Exec['refresh-apt-jenkins'],
      Package[$java_package],
    ]
  }

  package { [ 'jenkins-debian-glue',
            'jenkins-debian-glue-buildenv' ]:
    ensure  => present,
  }

  service { 'jenkins':
    ensure  => running,
    require => [
      Package['jenkins'],
    ]
  }

  package { 'sudo':
    ensure => present,
  }

  file { '/etc/sudoers.d/jenkins':
    mode    => '0440',
    content => '## Deployed via jenkins_debian_glue.pp

# Make sure DEB_* options reach cowbuilder, like e.g.:
#  export DEB_BUILD_OPTIONS="parallel=8" /usr/bin/jdg-build-and-provide-package
Defaults  env_keep+="DEB_* DIST ARCH ADT MIRRORSITE"

# for *-binaries job
jenkins ALL=NOPASSWD: /usr/sbin/cowbuilder, /usr/sbin/chroot
# for *-piuparts job
jenkins ALL=NOPASSWD: /usr/sbin/piuparts, /usr/sbin/debootstrap, /usr/bin/jdg-piuparts-wrapper
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
        <url>https://github.com/mika/jenkins-debian-glue.git</url>
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
/usr/bin/jdg-generate-git-snapshot

# when using subversion:
# /usr/bin/jdg-generate-svn-snapshot</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>mkdir -p report
/usr/bin/jdg-lintian-junit-report *.dsc &gt; report/lintian.xml</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>*.gz,*.bz2,*.xz,*.deb,*.dsc,*.git,*.changes,*.buildinfo,lintian.txt</artifacts>
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
        <string>${::jdg_debian_arch}</string>
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
/usr/bin/jdg-build-and-provide-package</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>echo &quot;Listing packages inside the jenkins-debian-glue repository:&quot;
/usr/bin/jdg-repository-checker --list-repos jenkins-debian-glue</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>mkdir -p report
/usr/bin/jdg-lintian-junit-report *.dsc &gt; report/lintian.xml</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers>
    <hudson.tasks.ArtifactArchiver>
      <artifacts>*.gz,*.bz2,*.xz,*.deb,*.dsc,*.git,*.changes,*.buildinfo,lintian.txt</artifacts>
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
    require => File['/var/lib/jenkins/jobs/jenkins-debian-glue-piuparts/'],
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
          <defaultValue>${::jdg_debian_arch}</defaultValue>
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
sudo jdg-piuparts-wrapper \${PWD}/artifacts/*.deb || true</command>
    </hudson.tasks.Shell>
    <hudson.tasks.Shell>
      <command>jdg-tap-piuparts piuparts.txt &gt; piuparts.tap</command>
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

}

## software
include jenkins::repos
include jenkins::software
include jenkins::config
include jenkins::reprepro
