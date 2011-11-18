SERVER:="http://192.168.51.134:8080"

upload: upload-binaries-templates upload-git-templates upload-svn-templates

upload-binaries-templates:
	curl -H "Content-Type: text/xml" -s --data '@template-binaries.xml' $(SERVER)/createItem?name=__template-binaries

upload-git-templates:
	curl -H "Content-Type: text/xml" -s --data "@template-source-git.xml" $(SERVER)/createItem?name=__template-source-git

upload-svn-templates:
	curl -H "Content-Type: text/xml" -s --data "@template-source-svn.xml" $(SERVER)/createItem?name=__template-source-svn


