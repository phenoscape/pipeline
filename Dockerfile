
### 1. Get Linux
FROM ubuntu:18.04

ENV ROBOT v1.5.0
ARG ROBOT_JAR=https://github.com/ontodev/robot/releases/download/$ROBOT/robot.jar
ENV ROBOT_JAR ${ROBOT_JAR}
ENV DOSDPVERSION=0.13.1
ENV JENA=3.12.0
ENV BGR=1.4
ENV KBOT=1.9.1


### 2. Get Java and all required system libraries
RUN apt-get update && apt-get upgrade -y \
 && apt-get install -y software-properties-common \
  build-essential git \
  openjdk-8-jre openjdk-8-jdk

RUN apt-get update \
    && apt-get install -y make curl git wget tar

### 3. Install custom tools
WORKDIR /tools

###### JENA ######
RUN curl -O -L http://archive.apache.org/dist/jena/binaries/apache-jena-$JENA.tar.gz \
    && tar -zxf apache-jena-$JENA.tar.gz

###### ROBOT ######
RUN curl -O -L https://github.com/ontodev/robot/releases/download/v$ROBOT/robot.jar \
    && curl -O -L https://github.com/ontodev/robot/raw/v$ROBOT/bin/robot \
    && chmod +x robot

# Avoid repeated downloads of script dependencies by mounting the local coursier cache:
# docker run -v $HOME/.coursier/cache/v1:/tools/.coursier-cache ...
ENV COURSIER_CACHE "/tools/.coursier-cache"

###### DOSDPTOOLS ######
ENV PATH "/tools/dosdp-tools/bin:$PATH"
RUN wget -nv https://github.com/INCATools/dosdp-tools/releases/download/v$DOSDPVERSION/dosdp-tools-$DOSDPVERSION.tgz \
&& tar -zxvf dosdp-tools-$DOSDPVERSION.tgz \
&& mv dosdp-tools-$DOSDPVERSION /tools/dosdp-tools \
&& wget --no-check-certificate https://raw.githubusercontent.com/INCATools/dead_simple_owl_design_patterns/master/src/simple_pattern_tester.py -O /tools/simple_pattern_tester.py

###### BLAZEGRPAH-RUNNER ######
RUN curl -O -L https://github.com/balhoff/blazegraph-runner/releases/download/v$BGR/blazegraph-runner-$BGR.tgz \
&& tar -zxf blazegraph-runner-$BGR.tgz

###### KB-OWL-TOOLS ######
RUN curl -O -L https://github.com/phenoscape/phenoscape-owl-tools/releases/download/v$KBOT/kb-owl-tools-$KBOT.tgz \
&& tar -zxf kb-owl-tools-$KBOT.tgz

RUN chmod +x /tools/*

#CMD["make", "all"]