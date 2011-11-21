#!/usr/bin/ruby
# Filename:      config-builder.rb
# Purpose:       build jenkins-debian-glue related config.ymls for Jenkins
################################################################################

require 'xmlsimple'

# TODO
# must specify:
# --jobname name
# --role source | binaries | repos | all (applies source/binaries/repos all at once)
#
# --noremote
# --basedirectory [/path/to/jobs/ for jobname-{source,binaries,repos}
#   vs
# --server server
# --user user
# --password password
#
# --scm git | svn | manual
#
# optional:
#
# --keyid
# --noplugins

# configs
# TODO - move to separate config file, support setting via cmdline
job = "foobar"
jenkins_host = "http://example.org"
key_id = "DEADBEEF"

$source_description = "Building a Debian source package of #{job}.&lt;br&gt;&#xd;
&lt;br&gt;&#xd;
APT instructions:&lt;br&gt;&#xd;
&lt;pre&gt;&#xd;
deb     #{jenkins_host}/debian #{job} main&#xd;
deb-src #{jenkins_host}/debian #{job} main&#xd;
wget -O - #{jenkins_host}/debian/#{key_id}.asc | sudo apt-key add - &#xd;
&lt;/pre&gt;"

$binaries_description = "Building Debian binary packages of #{job}.&lt;br&gt;&#xd;
&lt;br&gt;&#xd;
APT instructions:&lt;br&gt;&#xd;
&lt;pre&gt;&#xd;
deb     #{jenkins_host}/debian ngcpcfg main&#xd;
deb-src #{jenkins_host}/debian ngcpcfg main&#xd;
wget -O - #{jenkins_host}/debian/#{key_id}.asc | sudo apt-key add - &#xd;
&lt;/pre&gt;"

$repos_description = "Including Debian packages of #{job} into a repository.&lt;br&gt;&#xd;
&lt;br&gt;&#xd;
APT instructions:&lt;br&gt;&#xd;
&lt;pre&gt;&#xd;
deb     #{jenkins_host}/debian ngcpcfg main&#xd;
deb-src #{jenkins_host}/debian ngcpcfg main&#xd;
wget -O - #{jenkins_host}/debian/#{key_id}.asc | sudo apt-key add - &#xd;
&lt;/pre&gt;"

def generateSourceConfig(input_file, output_file)
  config = XmlSimple.xml_in(input_file, 'KeepRoot'=>true)
  root=config.keys[0];

  # debugging:
  p config

  config[root][0]['description']=[$source_description]
  config[root][0]['scm']=[
    { "class" => "hudson.scm.SubversionSCM",
        'locations'=> { 'hudson.scm.SubversionSCM_-ModuleLocation' => {'remote' => ["https://vcs.example.org/todo"]}},
        'excludedRegions' => [''],
        'includedRegions' => [''],
        'excludedUsers' => [''],
        'excludedRevprop' => [''],
        'excludedCommitMessages' => [''],
    }
  ]
# possible TODO ->  <workspaceUpdater class="hudson.scm.subversion.UpdateUpdater"/>

  output = XmlSimple.xml_out(config,'KeepRoot'=>true, 'OutputFile'=>output_file, 'XmlDeclaration'=>"<?xml version='1.0' encoding='UTF-8'?>")
end

generateSourceConfig("template-source-svn.xml", "mika.xml")

#def createJenkinsJob()
#  require "uri"
#  require "net/http"
#  uri = URI.new $ENV['SERVER'] + '/createItem?name=__template-binaries'
#  http = Net::HTTP.new(uri.host, uri.port)
#  request = Net::HTTP::Post.new(uri.request_uri)
#  request.body = File.read('template-binaries.xml')
#  request["Content-Type"] = "text/xml"
#  append http.request(request)
#end

## END OF FILE #################################################################
