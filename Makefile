PREFIX := /usr

PROGRAMS := build-and-provide-package generate-git-snapshot generate-local-repository generate-reprepro-codename generate-svn-snapshot

build:
	@echo nothing to do

install: $(scripts)
	mkdir -p $(DESTDIR)/$(PREFIX)/bin/
	for prog in $(PROGRAMS); do \
		install -m 0755 $$prog $(DESTDIR)/$(PREFIX)/bin; \
	done

.PHONY: install
