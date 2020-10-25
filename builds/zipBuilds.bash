#!/bin/bash

rm -rf BuildZips
mkdir BuildZips

zip BuildZips/Windows64.zip Windows64/*
zip BuildZips/Windows32.zip Windows32/*

tar --exclude=".*" -cvzf BuildZips/Linux64.tar.gz Linux64
tar --exclude=".*" -cvzf BuildZips/Linux32.tar.gz Linux32

cp MacOS/TSAGame2021.zip BuildZips/MacOS.zip
cp Windows32/TSAGame2021.pck BuildZips/
