munged: ../munged/.patched

../munged/.patched: $(wildcard ../src/*.sol) applyMunging.patch
	@mkdir -p ../munged
	@cp -r $(filter-out ../src/v1.1,$(wildcard ../src/*)) ../munged
	@patch -p0 -d ../munged < applyMunging.patch
	@touch $@

record:
	diff -ruN --exclude=v1.1 --exclude=.patched ../src ../munged | sed -E 's,\.\./src/|\.\./munged/,,g' | sed -E 's,((\-\-\-|\+\+\+) [^[:space:]]*).*,\1,' > applyMunging.patch

clean:
	rm -rf ../munged

.PHONY: help clean # do not add munged here, as it is useful to protect munged edits
