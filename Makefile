#inspired by http://bost.ocks.org/mike/make/

DATA_DIR=data_files
APP_DIR=app

SR_FILES=$(DATA_DIR)/SR2010.xlsx $(DATA_DIR)/SR2011.xlsx $(DATA_DIR)/SR2012.xlsx $(DATA_DIR)/SR2013.xlsx $(DATA_DIR)/SR2014.xlsx $(DATA_DIR)/SR2015.xlsx

all: $(APP_DIR)/fsas.json $(APP_DIR)/request_types.csv $(APP_DIR)/ts.csv

#
# 311 Service Requests - Customer Initiated
#
$(DATA_DIR)/%.xlsx:
	curl -o $(DATA_DIR)/$(*F).zip 'http://opendata.toronto.ca/311/service.request/$(*F).zip'
	unzip $(DATA_DIR)/$(*F).zip -d $(DATA_DIR)
	touch $@

$(DATA_DIR)/sr.db:
	sqlite3 $(DATA_DIR)/sr.db < db.sql

load_db: $(DATA_DIR)/sr.db $(SR_FILES)
	python load_db.py $^


##
## Canada-wide FSA bountries shape file from StatsCan 2011 census
##

#grab file from StatsCan
$(DATA_DIR)/gfsa000a11a_e.zip:
	curl -o $@ 'http://www12.statcan.gc.ca/census-recensement/2011/geo/bound-limit/files-fichiers/gfsa000a11a_e.zip'

#Extract the FSA bountries shipfile
$(DATA_DIR)/gfsa000a11a_e.shp: $(DATA_DIR)/gfsa000a11a_e.zip
	unzip $< -d $(DATA_DIR)
	touch $@

#Census population data per fsa
$(DATA_DIR)/population.csv:
	curl -J "http://www12.statcan.gc.ca/census-recensement/2011/dp-pd/hlt-fst/pd-pl/FullFile.cfm?T=1201&LANG=Eng&OFT=CSV&OFN=98-310-XWE2011002-1201.CSV" | grep "^M" > $(DATA_DIR)/tmp
	{ echo "CFSAUID,dummy1,Population,dummy2,dummy3"; cat $(DATA_DIR)/tmp; } > $@

#Convert bountries to a TopoJSON file (https://github.com/mbostock/topojson)
#
# Including:
# CFSAUID -- FSA id
#
# Ignoring:
# PRUID -- Province id
# PRNAME -- Province name
$(DATA_DIR)/fsas.geojson: $(DATA_DIR)/gfsa000a11a_e.shp
	ogr2ogr -f GeoJSON -where "CFSAUID LIKE 'M%'" $@ $<

$(APP_DIR)/fsas.json: $(DATA_DIR)/fsas.geojson $(DATA_DIR)/population.csv $(DATA_DIR)/fsas.csv
	topojson \
	 -e $(DATA_DIR)/population.csv \
	 -e $(DATA_DIR)/fsas.csv \
	 --id-property CFSAUID,location \
	 -p \
	 -o $@ \
	 -- $<

$(DATA_DIR)/fsas.csv $(APP_DIR)/ts.csv: $(DATA_DIR)/sr.db 
	python process_fsas.py $< $(DATA_DIR)/fsas.csv $(APP_DIR)/ts.csv

$(APP_DIR)/request_types.csv: $(DATA_DIR)/sr.db
	echo "request_types" > $@
	sqlite3 $< -csv "select distinct type from sr where location is not null order by 1" >> $@


clean:
	rm -rf $(DATA_DIR)/* $(APP_DIR)/fsas.json
