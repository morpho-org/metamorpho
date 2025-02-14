munged: ../munged

../munged: $(wildcard ../src/*.sol) applyMunging.patch
	@rm -rf ../munged
	@cp -r ../src ../munged
	@patch -p0 -d ../munged < applyMunging.patch

record:
	diff -ruN ../src ../munged | sed -E 's,\.\./src/|\.\./munged/,,g' | sed -E 's,((\-\-\-|\+\+\+) [^[:space:]]*).*,\1,' > applyMunging.patch

clean:
	rm -rf ../munged

.PHONY: help clean # do not add munged here, as it is useful to protect munged edits
