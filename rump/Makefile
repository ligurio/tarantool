CHOST ?= x86_64-rumprun-netbsd
CBUILDROOT ?= /usr/rumprun-x86_64

all:
	cd .. && ${CHOST}-cmake . \
		-DCMAKE_BUILD_TYPE=$${CMAKE_BUILD_TYPE:-RelWithDebInfo} \
		-DENABLE_BUNDLED_LIBYAML=ON \
		-DENABLE_DIST=OFF
	$(MAKE) -C .. $(MAKEOPTS) tarantool
	cp -p ../src/tarantool ../../tarantool
