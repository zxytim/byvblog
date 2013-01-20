#!/bin/bash
for i in `find -name '*.coffee'`; do
	rm ${i%.*}.js -rf
done
