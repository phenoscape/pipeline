#!/bin/sh

KBOT=1.8
DOSDP=0.13.1
JENA=3.12.0
BGR=1.4
ROBOT=1.4.3

mkdir -p bin
cd bin

curl -O -L https://github.com/phenoscape/phenoscape-owl-tools/releases/download/v$KBOT/kb-owl-tools-$KBOT.tgz
tar -zxf kb-owl-tools-$KBOT.tgz

curl -O -L https://github.com/INCATools/dosdp-tools/releases/download/v$DOSDP/dosdp-tools-$DOSDP.tgz
tar -zxf dosdp-tools-$DOSDP.tgz

curl -O -L https://www-us.apache.org/dist/jena/binaries/apache-jena-$JENA.tar.gz
tar -zxf apache-jena-$JENA.tar.gz

curl -O -L https://github.com/balhoff/blazegraph-runner/releases/download/v$BGR/blazegraph-runner-$BGR.tgz
tar -zxf blazegraph-runner-$BGR.tgz

curl -O -L https://github.com/ontodev/robot/releases/download/v$ROBOT/robot.jar
curl -O -L https://github.com/ontodev/robot/raw/v$ROBOT/bin/robot
chmod +x robot

pip install virtualenv
mkdir python-virtual-environments && cd python-virtual-environments
virtualenv env

cd ../..

export PATH=bin:bin/kb-owl-tools-$KBOT/bin:bin/dosdp-tools-$DOSDP/bin:bin/apache-jena-$JENA/bin:bin/blazegraph-runner-$BGR/bin:bin/python-virtual-environments/env/bin:/usr/bin:/bin
