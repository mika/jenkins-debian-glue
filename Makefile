PREFIX := /usr

PROGRAMS := scripts/*

build:
	tests/increase-version-number

install: $(scripts)
	mkdir -p $(DESTDIR)/$(PREFIX)/bin/
	for prog in $(PROGRAMS); do \
		install -m 0755 $$prog $(DESTDIR)/$(PREFIX)/bin; \
	done

	mkdir -p $(DESTDIR)/usr/share/jenkins-debian-glue/examples/
	install -m 0664 examples/* $(DESTDIR)/usr/share/jenkins-debian-glue/examples/

deploy:
	fab all

clean:
	rm -f fabfile.pyc
	# avoid recursion via debian/rules clean, so manually rm:
	rm -f debian/files debian/jenkins-debian-glue.debhelper.log
	rm -f debian/jenkins-debian-glue.substvars
	rm -rf debian/jenkins-debian-glue/

.PHONY: build install
