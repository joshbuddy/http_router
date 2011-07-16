#!/bin/sh

coffee -c spec/spec_generate.coffee && node spec/spec_generate.js
coffee -c spec/spec_recognize.coffee && node spec/spec_recognize.js

