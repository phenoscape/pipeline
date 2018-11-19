# Overview
Build pipeline for the Phenoscape Knowledgebase


## Aims
Current version of the [pipeline](https://github.com/phenoscape/phenoscape-owl-tools/tree/master/pipeline) to be replaced with a newer version built in accordance with the following aims:

* Modularize the pipeline
* Institute quality control measures
* Use generic (commoditized) tools ([robot](http://robot.obolibrary.org/), [dosdp](https://github.com/INCATools/dead_simple_owl_design_patterns), etal)

## Projects

### Pipeline Refactoring
1. Loading and reasoning core Phenoscape data
2. Auto-generating axioms
3. Importing Model Organism data
4. Semantic similarity

### Quality Control Automation
* Create automated test suite for all the parts of the pipeline
* Formal and machine-testable definitions of OWL/RDF model expectations
    * ShEx
    * SHACL
    * SPARQL Queries
    
    
***

## Deployment

### Dependencies
To successfully build and run the project, you need to have the following softwares installed:

1. [Robot](https://github.com/ontodev/robot)
2. [Phenoscape OWL tools](https://github.com/phenoscape/phenoscape-owl-tools) 

### Usage

Execute `make all` on commandline to build the pipeline.


# Documentation

The build workflow can be found [here](https://github.com/phenoscape/pipeline/blob/master/docs/kb-build-flow.pdf).

The build process involves 

1. Importing/mirroring ontologies given in [ontologies.ofn](https://github.com/phenoscape/pipeline/blob/master/ontologies.ofn)
2. Downloading data annotated by curators using Phenex (NeXML files)
3. Downloading ontologies developed by the [MONARCH Initiative](https://monarchinitiative.org/) - MGI, ZFIN, HPOA

All these ontologies are merged into a single ontology, reasoned over to generate tbox and abox axioms, and finally combined together to form the Phenoscape-KB.

`ontology-versions.ttl` contains metadata about the ontologies used in a particular kb build.
