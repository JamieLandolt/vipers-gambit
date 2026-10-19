#!/bin/sh
cd "$(dirname "$0")/.." && luajit tests/test.lua
