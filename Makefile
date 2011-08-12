PREFIX := /usr

PROGRAMS := build-and-provide-package generate-git-snapshot generate-local-repository generate-reprepro-codename generate-svn-snapshot increase-version-number

build:
	tests/increase-version-number

install: $(scripts)
	mkdir -p $(DESTDIR)/$(PREFIX)/bin/
	for prog in $(PROGRAMS); do \
		install -m 0755 $$prog $(DESTDIR)/$(PREFIX)/bin; \
	done

.PHONY: build install
