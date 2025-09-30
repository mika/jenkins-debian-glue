PREFIX := /usr

PROGRAMS := scripts/* tap/*

all: build

build:

check: build
	tests/merge-conflict
	tests/increase-version-number
	tests/file-detection

install: $(scripts)
	mkdir -p $(DESTDIR)/$(PREFIX)/bin/
	for prog in $(PROGRAMS); do \
		install -m 0755 $$prog $(DESTDIR)/$(PREFIX)/bin; \
	done

	mkdir -p $(DESTDIR)/usr/share/jenkins-debian-glue/examples/
	install -m 0664 examples/* $(DESTDIR)/usr/share/jenkins-debian-glue/examples/
	mkdir -p $(DESTDIR)/usr/share/jenkins-debian-glue/pbuilder-hookdir/
	install -m 0775 pbuilder-hookdir/* $(DESTDIR)/usr/share/jenkins-debian-glue/pbuilder-hookdir/

uninstall: $(scripts)
	for prog in $(PROGRAMS); do \
		rm $(DESTDIR)/$(PREFIX)/bin/$${prog#scripts} ; \
	done
	rm -rf $(DESTDIR)/usr/share/jenkins-debian-glue/examples
	rmdir --ignore-fail-on-non-empty $(DESTDIR)/usr/share/jenkins-debian-glue

deploy:
	fab all

clean:
	rm -f fabfile.pyc

.PHONY: all build check install uninstall deploy clean
