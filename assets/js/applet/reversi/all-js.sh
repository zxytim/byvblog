#!/bin/bash
for i in `find -name '*.coffee'`; do
	continuation $i -e -c -p > ${i%.*}.js
done
