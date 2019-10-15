#JAVA_OPTS="-Xmx70G"


BUILD_DIR=build
RESOURCES=resources
SPARQL=sparql
JAVA_HEAP ?= -Xmx128G
ROBOT_ENV=ROBOT_JAVA_ARGS=$(JAVA_HEAP)
ROBOT=$(ROBOT_ENV) robot
JVM_ARGS=JVM_ARGS=$(JAVA_HEAP)
ARQ=$(JVM_ARGS) arq
RIOT=riot
BLAZEGRAPH-RUNNER=blazegraph-runner

BIO_ONTOLOGIES=ontologies.ofn
# Path to data repo; must be separately downloaded/cloned
NEXML_DATA=phenoscape-data
DB_FILE=$(BUILD_DIR)/blazegraph-loaded-all.jnl
BLAZEGRAPH_PROPERTIES=$(RESOURCES)/blazegraph.properties



# ---------------------------------------------------------------------

clean:
	rm -rf $(BUILD_DIR)


# ########## # ##########
# ########## # ##########

# Modules:
# 1. KB build
# 2. Semantic similarity


all: kb-build ss-scores-gen $(DB_FILE)

# ########## # ##########
# ########## # ##########


# ********** * **********


# ########## # ##########
# ########## # ##########

# Module 1 ---> KB build

# ########## # ##########

# Products
# 1. Phenoscape KB
# 2. Phenoscape KB TBox Hierarchy


kb-build: $(BUILD_DIR)/phenoscape-kb.ttl $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl

# ########## # ##########


# ##########
# 1. Phenoscape KB

$(BUILD_DIR)/phenoscape-kb.ttl: $(BUILD_DIR)/ontology-metadata.ttl \
                                $(BUILD_DIR)/phenex-data+tbox.ttl \
                                $(BUILD_DIR)/monarch-data-merged.ttl \
                                $(BUILD_DIR)/gene-profiles.ttl $(BUILD_DIR)/absences.ttl $(BUILD_DIR)/presences.ttl $(BUILD_DIR)/evolutionary-profiles.ttl \
                                $(BUILD_DIR)/subclass-closure.ttl $(BUILD_DIR)/instance-closure.ttl
	$(RIOT) --verbose --nocheck --output=NTRIPLES \
    	$(BUILD_DIR)/ontology-metadata.ttl \
    	$(BUILD_DIR)/phenex-data+tbox.ttl \
    	$(BUILD_DIR)/monarch-data-merged.ttl \
    	$(BUILD_DIR)/gene-profiles.ttl \
    	$(BUILD_DIR)/absences.ttl \
    	$(BUILD_DIR)/presences.ttl \
    	$(BUILD_DIR)/evolutionary-profiles.ttl \
    	$(BUILD_DIR)/subclass-closure.ttl \
    	$(BUILD_DIR)/instance-closure.ttl \
    	> $@.tmp \
      && mv $@.tmp $@
      


# ----------

# 2. Phenoscape KB TBox Hierarchy

# Compute Tbox hierarchy
$(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl: $(BUILD_DIR)/phenoscape-kb-tbox-classified.ttl $(SPARQL)/subclassHierarchy.sparql
	$(ARQ) --data=$< --query=$(SPARQL)/subclassHierarchy.sparql --results=ttl > $@.tmp \
	&& mv $@.tmp $@

# ##########


# ##########
# Component 1 --> Imported bio-ontologies' metadata

# Extract ontology metadata
# ## Query for ontologies' version information
$(BUILD_DIR)/ontology-metadata.ttl: $(BIO_ONTOLOGIES) $(SPARQL)/ontology-versions.sparql
	$(ROBOT) query \
	--catalog $(BUILD_DIR)/mirror/catalog-v001.xml \
	-i $< \
	--use-graphs true \
	--format ttl \
	--query $(SPARQL)/ontology-versions.sparql $@.tmp \
	&& mv $@.tmp $@

# ----------

# Mirror ontologies locally
# $(ONTOLOGIES) - list of ontologies to be imported
$(BUILD_DIR)/mirror: $(BIO_ONTOLOGIES)
	rm -rf $@ ; \
	$(ROBOT) mirror -i $< -d $@ -o $@/catalog-v001.xml

# ##########


# ##########
# Component 2 --> Phenex data + TBox

# Create Phenex data + TBox KB
$(BUILD_DIR)/phenex-data+tbox.ttl: $(BUILD_DIR)/phenex-data-merged.ofn $(BUILD_DIR)/phenoscape-kb-tbox-classified.ttl
	$(ROBOT) merge \
    	-i $(BUILD_DIR)/phenex-data-merged.ofn \
    	-i $(BUILD_DIR)/phenoscape-kb-tbox-classified.ttl \
    	convert --format ttl \
    	-o $@.tmp \
    	&& mv $@.tmp $@

# ----------

# Store paths to all needed Phenex NeXML files in NEXMLS variable
NEXMLS ?= $(shell mkdir -p $(BUILD_DIR)) \
$(shell find $(NEXML_DATA)/curation-files/completed-phenex-files -type f -name "*.xml") \
$(shell find $(NEXML_DATA)/curation-files/fin_limb-incomplete-files -type f -name "*.xml") \
$(shell find $(NEXML_DATA)/curation-files/Jackson_Dissertation_Files -type f -name "*.xml") \
$(shell find $(NEXML_DATA)/curation-files/teleost-incomplete-files/Miniature_Monographs -type f -name "*.xml") \
$(shell find $(NEXML_DATA)/curation-files/teleost-incomplete-files/Miniatures_Matrix_Files -type f -name "*.xml") \
$(shell find $(NEXML_DATA)/curation-files/matrix-vs-monograph -type f -name "*.xml")

# Store paths to all OFN files which will be produced from NeXML files in NEXML_OWLS variable
NEXML_OWLS ?= $(patsubst %.xml, %.ofn, $(patsubst $(NEXML_DATA)/%, $(BUILD_DIR)/phenex-data-owl/%, $(NEXMLS)))

# Convert a single NeXML file to its counterpart OFN
$(BUILD_DIR)/phenex-data-owl/%.ofn: $(NEXML_DATA)/%.xml $(BUILD_DIR)/bio-ontologies-merged.ttl
	mkdir -p $(dir $@)
	kb-owl-tools convert-nexml $(BUILD_DIR)/bio-ontologies-merged.ttl $< $@.tmp \
	&& mv $@.tmp $@


# Generate phenex-data-merged.ofn

# Merge all Phenex NeXML OFN files into a single ontology of phenotype annotations
$(BUILD_DIR)/phenex-data-merged.ofn: $(NEXML_OWLS)

	$(ROBOT) merge $(addprefix -i , $(NEXML_OWLS)) \
	convert --format ofn \
	-o $@.tmp \
	&& mv $@.tmp $@

# ----------

# Generate phenoscape-kb-tbox-classified.ofn

# Compute final inferred classification of Phenoscape KB Tbox
$(BUILD_DIR)/phenoscape-kb-tbox-classified.ttl: $(BUILD_DIR)/phenoscape-kb-tbox-classified-plus-absence.ttl
	$(ROBOT) reason \
    	--reasoner ELK \
    	--i $< \
    	convert --format ttl \
    	-o $@.tmp \
    	&& mv $@.tmp $@

# Generate phenoscape-kb-tbox-classified-plus-absence.ttl
$(BUILD_DIR)/phenoscape-kb-tbox-classified-plus-absence.ttl: $(BUILD_DIR)/phenoscape-kb-tbox-classified-pre-absence-reasoning.ofn $(BUILD_DIR)/negation-hierarchy.ofn
	$(ROBOT) merge \
	-i $(BUILD_DIR)/phenoscape-kb-tbox-classified-pre-absence-reasoning.ofn \
	-i $(BUILD_DIR)/negation-hierarchy.ofn \
	convert --format ttl \
	-o $@.tmp \
	&& mv $@.tmp $@

# ----------

# Generate negation-hierarchy.ofn
$(BUILD_DIR)/negation-hierarchy.ofn: $(BUILD_DIR)/phenoscape-kb-tbox-classified-pre-absence-reasoning.ofn
	kb-owl-tools assert-negation-hierarchy $< $@.tmp \
	&& mv $@.tmp $@

# ----------

# Generate phenoscape-kb-tbox-classified-pre-absence-reasoning.ofn
$(BUILD_DIR)/phenoscape-kb-tbox-classified-pre-absence-reasoning.ofn: $(BUILD_DIR)/phenoscape-kb-tbox.ofn
	$(ROBOT) reason \
	-i $< \
	convert --format ofn \
	-o $@.tmp \
	&& mv $@.tmp $@

# ----------

# Generate phenoscape-kb-tbox.ofn
$(BUILD_DIR)/phenoscape-kb-tbox.ofn: $(BUILD_DIR)/bio-ontologies-classified.ofn \
$(BUILD_DIR)/defined-by-links.ttl \
$(BUILD_DIR)/phenex-tbox.ofn \
$(BUILD_DIR)/anatomical-entity-presences.ofn \
$(BUILD_DIR)/anatomical-entity-absences.ofn \
$(BUILD_DIR)/anatomical-entity-partOf.ofn \
$(BUILD_DIR)/hasParts.ofn \
$(BUILD_DIR)/anatomical-entity-hasPartsInheringIns.ofn \
$(BUILD_DIR)/developsFromRulesForAbsence.ofn \
$(BUILD_DIR)/anatomical-entity-phenotypeOfs.ofn \
$(BUILD_DIR)/anatomical-entity-phenotypeOf-partOf.ofn \
$(BUILD_DIR)/anatomical-entity-phenotypeOf-developsFrom.ofn
	$(ROBOT) merge \
	-i $(BUILD_DIR)/bio-ontologies-classified.ofn \
	-i $(BUILD_DIR)/defined-by-links.ttl \
	-i $(BUILD_DIR)/phenex-tbox.ofn \
    -i $(BUILD_DIR)/anatomical-entity-presences.ofn \
    -i $(BUILD_DIR)/anatomical-entity-absences.ofn \
    -i $(BUILD_DIR)/anatomical-entity-partOf.ofn \
    -i $(BUILD_DIR)/hasParts.ofn \
    -i $(BUILD_DIR)/anatomical-entity-hasPartsInheringIns.ofn \
    -i $(BUILD_DIR)/developsFromRulesForAbsence.ofn \
    -i $(BUILD_DIR)/anatomical-entity-phenotypeOfs.ofn \
    -i $(BUILD_DIR)/anatomical-entity-phenotypeOf-partOf.ofn \
    -i $(BUILD_DIR)/anatomical-entity-phenotypeOf-developsFrom.ofn \
    convert --format ofn \
	-o $@.tmp \
	&& mv $@.tmp $@

# ----------

# *** Subsumers ***

# -----

$(BUILD_DIR)/defined-by-links.ttl: $(BUILD_DIR)/bio-ontologies-classified.ofn $(SPARQL)/isDefinedBy.sparql
	$(ROBOT) query \
	--use-graphs true \
	--format ttl \
	--input $< \
	--query $(SPARQL)/isDefinedBy.sparql $@

$(BUILD_DIR)/anatomical-entity-presences.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/implies_presence_of.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/implies_presence_of.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/anatomical-entity-absences.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/absences.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/absences.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/anatomical-entity-partOf.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/part_of.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/part_of.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/hasParts.ofn: $(BUILD_DIR)/anatomical-entities.txt $(BUILD_DIR)/qualities.txt patterns/has_part.yaml
	mkdir -p $(dir $@) \
	&& sed '1d' $(BUILD_DIR)/qualities.txt > $(BUILD_DIR)/qualities--header.txt \
	&& cat $(BUILD_DIR)/anatomical-entities.txt $(BUILD_DIR)/qualities--header.txt > $(BUILD_DIR)/anatomical-entities++qualities.txt \
	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/has_part.yaml \
    	--infile=$(BUILD_DIR)/anatomical-entities++qualities.txt \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/anatomical-entity-hasPartsInheringIns.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/has_part_inhering_in.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/has_part_inhering_in.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/developsFromRulesForAbsence.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/develops_from_rule.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/develops_from_rule.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/anatomical-entity-phenotypeOfs.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/phenotype_of.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/phenotype_of.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/anatomical-entity-phenotypeOf-partOf.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/phenotype_of_part_of.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/phenotype_of_part_of.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

$(BUILD_DIR)/anatomical-entity-phenotypeOf-developsFrom.ofn: $(BUILD_DIR)/anatomical-entities.txt patterns/phenotype_of_develops_from.yaml
	mkdir -p $(dir $@) \
    	&& dosdp-tools generate \
    	--generate-defined-class=true \
    	--obo-prefixes=true \
    	--template=patterns/phenotype_of_develops_from.yaml \
    	--infile=$< \
    	--outfile=$@.tmp \
    	&& mv $@.tmp $@

# -----

# Generate anatomical-entities.txt
$(BUILD_DIR)/anatomical-entities.txt: $(BUILD_DIR)/bio-ontologies-merged.ttl $(BUILD_DIR)/defined-by-links.ttl $(SPARQL)/anatomicalEntities.sparql
	$(ARQ) \
    	--data=$< \
    	--data=$(BUILD_DIR)/defined-by-links.ttl \
    	--results=TSV \
    	--query=$(SPARQL)/anatomicalEntities.sparql > $@.tmp \
    	&& sed -i '1d' $@.tmp \
    	&& mv $@.tmp $@

# Generate qualities.txt
$(BUILD_DIR)/qualities.txt: $(BUILD_DIR)/bio-ontologies-classified.ofn $(SPARQL)/qualities.sparql
	$(ROBOT) query \
    	-i $< \
    	--use-graphs true \
    	--query $(SPARQL)/qualities.sparql $@.tmp \
    	&& mv $@.tmp $@

# -----

# ----------

# Generate bio-ontologies-classified.ofn
# Compute inferred classification of just the input ontologies.
# We need to remove axioms that can infer unsatisfiability, since
# the input ontologies are not 100% compatible.
$(BUILD_DIR)/bio-ontologies-classified.ofn: $(BUILD_DIR)/bio-ontologies-merged.ttl
	$(ROBOT) remove -i $< --axioms 'disjoint' --trim true \
    remove --term 'owl:Nothing' --trim true \
    reason --reasoner ELK \
    convert --format ofn \
    -o $@.tmp \
    && mv $@.tmp $@

# Merge imported ontologies
$(BUILD_DIR)/bio-ontologies-merged.ttl: $(BIO-ONTOLOGIES) $(BUILD_DIR)/mirror
	$(ROBOT) merge \
	--catalog $(BUILD_DIR)/mirror/catalog-v001.xml \
	-i $< \
	convert --format ttl \
	-o $@.tmp \
	&& mv $@.tmp $@

# ----------

# Generate phenex-tbox.ofn
# Extract tbox and rbox from phenex-data-merged.ofn
$(BUILD_DIR)/phenex-tbox.ofn: $(BUILD_DIR)/phenex-data-merged.ofn
	$(ROBOT) filter \
	-i $< \
	--axioms tbox \
	--axioms rbox \
	convert --format ofn \
	-o $@.tmp \
	&& mv $@.tmp $@

# ----------

# ##########


# ##########
# Component 3 ---> Monarch data

# Monarch data
# 1. MGI
# 2. ZFIN
# 3. HPOA

# Merge monarch data files
$(BUILD_DIR)/monarch-data-merged.ttl: $(BUILD_DIR)/mgi_slim.ttl $(BUILD_DIR)/zfinslim.ttl $(BUILD_DIR)/hpoa.ttl
	$(ROBOT) merge \
	-i $(BUILD_DIR)/mgi_slim.ttl \
	-i $(BUILD_DIR)/zfinslim.ttl \
	-i $(BUILD_DIR)/hpoa.ttl \
	convert --format ttl \
	-o $@.tmp \
	&& mv $@.tmp $@

# Download mgi_slim.ttl
$(BUILD_DIR)/mgi_slim.ttl:
	mkdir -p $(BUILD_DIR)
	curl -L https://data.monarchinitiative.org/ttl/mgi_slim.ttl -o $@.tmp \
	&& mv $@.tmp $@

# Download zfinslim.ttl
$(BUILD_DIR)/zfinslim.ttl:
	mkdir -p $(BUILD_DIR)
	curl -L https://data.monarchinitiative.org/ttl/zfinslim.ttl -o $@.tmp \
	&& mv $@.tmp $@

# Download hpoa.ttl
$(BUILD_DIR)/hpoa.ttl:
	mkdir -p $(BUILD_DIR)
	curl -L https://data.monarchinitiative.org/ttl/hpoa.ttl -o $@.tmp \
	&& mv $@.tmp $@

# ##########


# ##########
# Component 4 ----> Profiles

# Generate gene-profiles.ttl
$(BUILD_DIR)/gene-profiles.ttl: $(BUILD_DIR)/monarch-data-merged.ttl $(SPARQL)/geneProfiles.sparql
	$(ROBOT) query \
    	-i $< \
    	--format ttl \
    	--query $(SPARQL)/geneProfiles.sparql $@.tmp \
    	&& mv $@.tmp $@

# Generate absences.ttl
$(BUILD_DIR)/absences.ttl: $(SPARQL)/absences.sparql $(BUILD_DIR)/subclass-closure.ttl  $(BUILD_DIR)/phenex-data+tbox.ttl 
	$(ARQ) \
	--data=$(BUILD_DIR)/phenex-data+tbox.ttl \
	--data=$(BUILD_DIR)/subclass-closure.ttl \
	--results=TSV \
	--query=$< > $@.tmp \
	&& sed -e '1d' -e 's/$$/ ./' -i $@.tmp \
	&& mv $@.tmp $@
	

# Generate presences.ttl
$(BUILD_DIR)/presences.ttl: $(SPARQL)/presences.sparql $(BUILD_DIR)/subclass-closure.ttl $(BUILD_DIR)/phenex-data+tbox.ttl
	$(ARQ) \
	--data=$(BUILD_DIR)/phenex-data+tbox.ttl \
	--data=$(BUILD_DIR)/subclass-closure.ttl \
	--results=TSV \
	--query=$< > $@.tmp \
	&& sed -e '1d' -e 's/$$/ ./' -i $@.tmp \
	&& mv $@.tmp $@



# Generate evolutionary-profiles.ttl
# Contains taxon-profiles data
$(BUILD_DIR)/evolutionary-profiles.ttl: $(BUILD_DIR)/phenex-data+tbox.ttl
	kb-owl-tools output-evolutionary-profiles $< $@.tmp \
	&& mv $@.tmp $@


# ##########



# ##########
# Component 5 ----> Closures

# Compute subclass closures
$(BUILD_DIR)/subclass-closure.ttl: $(BUILD_DIR)/phenoscape-kb-tbox-classified.ttl $(SPARQL)/subclass-closure-construct.sparql
	$(ARQ) \
	--data=$< \
	--optimize=off \
	--results=TSV \
	--query=$(SPARQL)/subclass-closure-construct.sparql > $@.tmp \
	&& sed -e '1d' -e 's/$$/ ./' -i $@.tmp \
	&& mv $@.tmp $@


# Compute instance closures
$(BUILD_DIR)/instance-closure.ttl: $(SPARQL)/profile-instance-closure-construct.sparql $(BUILD_DIR)/phenex-data+tbox.ttl $(BUILD_DIR)/gene-profiles.ttl $(BUILD_DIR)/evolutionary-profiles.ttl
	$(ARQ) \
	--data=$(BUILD_DIR)/phenex-data+tbox.ttl \
	--data=$(BUILD_DIR)/gene-profiles.ttl \
	--data=$(BUILD_DIR)/evolutionary-profiles.ttl \
	--results=NTRIPLES \
	--query=$< > $@.tmp \
	&& mv $@.tmp $@


# ##########


# ########## # ##########
# ########## # ##########


# ********** * **********


# ########## # ##########
# ########## # ##########

# Module 2 ---> Semantic similarity

# ########## # ##########

# Products
# 1. taxa-pairwise-sim.ttl
# 2. gene-pairwise-sim.ttl
# 3. taxa-expect-scores.ttl
# 4. gene-expect-scores.ttl

ss-scores-gen: $(BUILD_DIR)/taxa-pairwise-sim.ttl \
$(BUILD_DIR)/gene-pairwise-sim.ttl \
$(BUILD_DIR)/taxa-expect-scores.ttl \
$(BUILD_DIR)/gene-expect-scores.ttl


# ########## # ##########

# ##########
# Pairwise similarity for taxa

$(BUILD_DIR)/taxa-pairwise-sim.ttl: $(BUILD_DIR)/profiles.ttl $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl
	kb-owl-tools pairwise-sim 1 1 $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl $< taxa $@.tmp \
	&& mv $@.tmp $@

# ##########


# ##########
# Pairwise similarity for genes

$(BUILD_DIR)/gene-pairwise-sim.ttl: $(BUILD_DIR)/profiles.ttl $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl
	kb-owl-tools pairwise-sim 1 1 $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl $< genes $@.tmp \
	&& mv $@.tmp $@

# ##########


# ##########
# Generate expect scores for taxa and genes

$(BUILD_DIR)/taxa-expect-scores.ttl: $(BUILD_DIR)/taxa-rank-statistics.txt
	kb-owl-tools expects-to-triples $< $@.tmp \
	&& mv $@.tmp $@


$(BUILD_DIR)/taxa-rank-statistics.txt: $(BUILD_DIR)/taxa-scores.tsv $(RESOURCES)/regression.py $(BUILD_DIR)/profile-sizes.txt
	python $(RESOURCES)/regression.py `grep -v 'VTO_' $(BUILD_DIR)/profile-sizes.txt | wc -l` $< $@.tmp \
	&& mv $@.tmp $@

$(BUILD_DIR)/taxa-scores.tsv: $(SPARQL)/get-scores.rq $(BUILD_DIR)/corpus-ics-taxa.ttl $(BUILD_DIR)/taxa-pairwise-sim.ttl
	$(ARQ) \
	--data=$(BUILD_DIR)/corpus-ics-taxa.ttl \
	--data=$(BUILD_DIR)/taxa-pairwise-sim.ttl \
	--results=TSV \
	--query=$< > $@.tmp \
	&& mv $@.tmp $@

# ----------

$(BUILD_DIR)/gene-expect-scores.ttl: $(BUILD_DIR)/gene-rank-statistics.txt
	kb-owl-tools expects-to-triples $< $@.tmp \
	&& mv $@.tmp $@

$(BUILD_DIR)/gene-rank-statistics.txt: $(BUILD_DIR)/gene-scores.tsv $(RESOURCES)/regression.py $(BUILD_DIR)/profile-sizes.txt
	python $(RESOURCES)/regression.py `grep -v 'VTO_' $(BUILD_DIR)/profile-sizes.txt | wc -l` $< $@.tmp \
	&& mv $@.tmp $@

$(BUILD_DIR)/gene-scores.tsv: $(SPARQL)/get-scores.rq $(BUILD_DIR)/corpus-ics-genes.ttl $(BUILD_DIR)/gene-pairwise-sim.ttl
	$(ARQ) \
	--data=$(BUILD_DIR)/corpus-ics-genes.ttl \
	--data=$(BUILD_DIR)/gene-pairwise-sim.ttl \
	--results=TSV \
	--query=$< > $@.tmp \
	&& mv $@.tmp $@

# ----------

# Output profile sizes
$(BUILD_DIR)/profile-sizes.txt: $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl $(BUILD_DIR)/profiles.ttl
	kb-owl-tools output-profile-sizes $< $(BUILD_DIR)/profiles.ttl $@.tmp \
	&& mv $@.tmp $@

# ----------

$(BUILD_DIR)/corpus-ics-taxa.ttl: $(BUILD_DIR)/profiles.ttl $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl
	kb-owl-tools output-ics $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl $< taxa $@.tmp \
	&& mv $@.tmp $@

$(BUILD_DIR)/corpus-ics-genes.ttl: $(BUILD_DIR)/profiles.ttl $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl
	kb-owl-tools output-ics $(BUILD_DIR)/phenoscape-kb-tbox-hierarchy.ttl $< genes $@.tmp \
	&& mv $@.tmp $@

# ----------

# Generate profiles.ttl for genes and taxa
$(BUILD_DIR)/profiles.ttl: $(BUILD_DIR)/evolutionary-profiles.ttl $(BUILD_DIR)/gene-profiles.ttl
	$(ROBOT) merge \
	-i $(BUILD_DIR)/evolutionary-profiles.ttl \
	-i $(BUILD_DIR)/gene-profiles.ttl \
	convert --format ttl \
	-o $@.tmp \
	&& mv $@.tmp $@

# ##########

# ########## # ##########
# ########## # ##########





# ########## # ##########
# ########## # ##########


# ##########
# Load pipeline artifacts into Blazegraph database

# Artifacts:
# 1. Phenoscape KB
# 2. Closures = subclass + instance)
# 3. taxa-sim = taxa-ics + taxa-expect-scores + taxa-pairwise-sim
# 4. gene-sim = gene-ics + gene-expect-scores + gene-pairwise-sim

$(DB_FILE): $(BLAZEGRAPH_PROPERTIES) \
			$(BUILD_DIR)/phenoscape-kb.ttl \
			$(BUILD_DIR)/subclass-closure.ttl $(BUILD_DIR)/instance-closure.ttl \
			$(BUILD_DIR)/corpus-ics-taxa.ttl $(BUILD_DIR)/taxa-expect-scores.ttl $(BUILD_DIR)/taxa-pairwise-sim.ttl \
			$(BUILD_DIR)/corpus-ics-genes.ttl $(BUILD_DIR)/gene-expect-scores.ttl $(BUILD_DIR)/gene-pairwise-sim.ttl
	rm -f $@ && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/" $(BUILD_DIR)/phenoscape-kb.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/closure" $(BUILD_DIR)/subclass-closure.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/closure" $(BUILD_DIR)/instance-closure.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/taxa" $(BUILD_DIR)/corpus-ics-taxa.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/taxa" $(BUILD_DIR)/taxa-expect-scores.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/taxa" $(BUILD_DIR)/taxa-pairwise-sim.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/gene" $(BUILD_DIR)/corpus-ics-genes.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/gene" $(BUILD_DIR)/gene-expect-scores.ttl && \
 	$(BLAZEGRAPH-RUNNER) load --informat=turtle --journal=$@ --properties=$< --graph="http://kb.phenoscape.org/gene" $(BUILD_DIR)/gene-pairwise-sim.ttl

# ##########

# ########## # ##########
# ########## # ##########


# ########## # ########## # ########## # THE END # ########## # ########## # ########## #
