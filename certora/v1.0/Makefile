munged: ../../munged/v1.0

../../munged/v1.0: $(wildcard ../../src/v1.0/*.sol) applyMunging.patch
	@rm -rf ../../munged/v1.0
	@mkdir -p ../../munged
	@cp -r ../../src/v1.0 ../../munged/v1.0
	@patch -p0 -d ../../munged/v1.0 < applyMunging.patch

record:
	diff -ruN ../../src/v1.0 ../../munged/v1.0 | sed -E 's,\.\./\.\./src/v1\.[01]/|\.\./\.\./munged/v1\.[01]/,,g' | sed -E 's,((\-\-\-|\+\+\+) [^[:space:]]*).*,\1,' > applyMunging.patch

clean:
	rm -rf ../../munged/v1.0

.PHONY: clean record munged # Do not add ../../munged/v1.0 here, as it is useful to protect munged edits
