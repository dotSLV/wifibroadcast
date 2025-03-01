ARCH ?= $(shell uname -i)
PYTHON ?= /usr/bin/python3
COMMIT ?= $(shell git rev-parse HEAD)
VERSION ?= $(shell $(PYTHON) ./version.py $(shell git show -s --format="%ct" $(shell git rev-parse HEAD)) $(shell git rev-parse --abbrev-ref HEAD))

export VERSION COMMIT

_LDFLAGS := $(LDFLAGS) -lrt -lpcap -lsodium
_CFLAGS := $(CFLAGS) -Wall -O2 -DWFB_VERSION='"$(VERSION)-$(shell /bin/bash -c '_tmp=$(COMMIT); echo $${_tmp::8}')"'

all: all_bin gs.key test

env:
	virtualenv env --python=$(PYTHON)
	./env/bin/pip install --upgrade pip==20.2.3 setuptools==44.1.1 stdeb

all_bin: wfb_rx wfb_tx wfb_keygen

gs.key: wfb_keygen
	@if ! [ -f gs.key ]; then ./wfb_keygen; fi

src/%.o: src/%.c src/*.h
	$(CC) $(_CFLAGS) -std=gnu99 -c -o $@ $<

src/%.o: src/%.cpp src/*.hpp src/*.h
	$(CXX) $(_CFLAGS) -std=gnu++11 -c -o $@ $<

wfb_rx: src/rx.o src/radiotap.o src/fec.o src/wifibroadcast.o
	$(CXX) -o $@ $^ $(_LDFLAGS)

wfb_tx: src/tx.o src/fec.o src/wifibroadcast.o
	$(CXX) -o $@ $^ $(_LDFLAGS)

wfb_keygen: src/keygen.o
	$(CC) -o $@ $^ $(_LDFLAGS)

test:
	PYTHONPATH=`pwd` trial3 telemetry.tests

rpm:  all_bin env
	rm -rf dist
	./env/bin/python ./setup.py bdist_rpm --force-arch $(ARCH)
	rm -rf wifibroadcast.egg-info/

deb:  all_bin env
	rm -rf deb_dist
	./env/bin/python ./setup.py --command-packages=stdeb.command bdist_deb
	rm -rf wifibroadcast.egg-info/ wifibroadcast-$(VERSION).tar.gz

bdist: all_bin
	rm -rf dist
	$(PYTHON) ./setup.py bdist --plat-name linux-$(ARCH)
	rm -rf wifibroadcast.egg-info/

clean:
	rm -rf env wfb_rx wfb_tx wfb_keygen dist deb_dist build wifibroadcast.egg-info _trial_temp *~ src/*.o

