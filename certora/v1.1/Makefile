munged: ../../munged/v1.1

../../munged/v1.1: $(shell find ../../src/v1.1 -type f -name '*.sol') applyMunging.patch
	@rm -rf ../../munged/v1.1
	@mkdir -p ../../munged
	@cp -r ../../src/v1.1 ../../munged/v1.1
	@patch -p0 -d ../../munged/v1.1 < applyMunging.patch || { rm -rf ../../munged/v1.1; exit 1; }

record:
	diff -ruN ../../src/v1.1 ../../munged/v1.1 | sed -E 's,\.\./\.\./src/v1\.1/|\.\./\.\./munged/v1\.1/,,g' | sed -E 's,((\-\-\-|\+\+\+) [^[:space:]]*).*,\1,' > applyMunging.patch

clean:
	rm -rf ../../munged/v1.1

.PHONY: clean record munged # Do not add ../../munged/v1.1 here, as it is useful to protect munged edits
