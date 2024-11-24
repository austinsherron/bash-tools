LOCAL_BIN?=/usr/local/bin
SOURCE=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))


clean:
	deploy clean -s $(SOURCE) -n granica --pattern granica*

install:
	deploy install -s $(SOURCE) -n granica --pattern granica*

link:
	deploy link -s $(SOURCE) -n granica --pattern granica*
