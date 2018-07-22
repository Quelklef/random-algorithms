#!/bin/bash

mkdir -p data
rm -rf data/*
cd data
nim c -d:reckless -d:release --threads:on -r ../multiThread
