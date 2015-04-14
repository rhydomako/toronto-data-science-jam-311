#inspired by http://bost.ocks.org/mike/make/

DATA_DIR=data_files
APP_DIR=app

SR_FILES=$(DATA_DIR)/SR2010.xlsx $(DATA_DIR)/SR2011.xlsx $(DATA_DIR)/SR2012.xlsx $(DATA_DIR)/SR2013.xlsx $(DATA_DIR)/SR2014.xlsx $(DATA_DIR)/SR2015.xlsx
FSA_FILES=$(APP_DIR)/M1B.csv $(APP_DIR)/M1C.csv $(APP_DIR)/M1E.csv $(APP_DIR)/M1G.csv $(APP_DIR)/M1H.csv $(APP_DIR)/M1J.csv $(APP_DIR)/M1K.csv $(APP_DIR)/M1L.csv $(APP_DIR)/M1M.csv $(APP_DIR)/M1N.csv $(APP_DIR)/M1P.csv $(APP_DIR)/M1R.csv $(APP_DIR)/M1S.csv $(APP_DIR)/M1T.csv $(APP_DIR)/M1V.csv $(APP_DIR)/M1W.csv $(APP_DIR)/M1X.csv $(APP_DIR)/M2H.csv $(APP_DIR)/M2J.csv $(APP_DIR)/M2K.csv $(APP_DIR)/M2L.csv $(APP_DIR)/M2M.csv $(APP_DIR)/M2N.csv $(APP_DIR)/M2P.csv $(APP_DIR)/M2R.csv $(APP_DIR)/M3A.csv $(APP_DIR)/M3B.csv $(APP_DIR)/M3C.csv $(APP_DIR)/M3H.csv $(APP_DIR)/M3J.csv $(APP_DIR)/M3K.csv $(APP_DIR)/M3L.csv $(APP_DIR)/M3M.csv $(APP_DIR)/M3N.csv $(APP_DIR)/M4A.csv $(APP_DIR)/M4B.csv $(APP_DIR)/M4C.csv $(APP_DIR)/M4E.csv $(APP_DIR)/M4G.csv $(APP_DIR)/M4H.csv $(APP_DIR)/M4J.csv $(APP_DIR)/M4K.csv $(APP_DIR)/M4L.csv $(APP_DIR)/M4M.csv $(APP_DIR)/M4N.csv $(APP_DIR)/M4P.csv $(APP_DIR)/M4R.csv $(APP_DIR)/M4S.csv $(APP_DIR)/M4T.csv $(APP_DIR)/M4V.csv $(APP_DIR)/M4W.csv $(APP_DIR)/M4X.csv $(APP_DIR)/M4Y.csv $(APP_DIR)/M5A.csv $(APP_DIR)/M5B.csv $(APP_DIR)/M5C.csv $(APP_DIR)/M5E.csv $(APP_DIR)/M5G.csv $(APP_DIR)/M5H.csv $(APP_DIR)/M5J.csv $(APP_DIR)/M5K.csv $(APP_DIR)/M5L.csv $(APP_DIR)/M5M.csv $(APP_DIR)/M5N.csv $(APP_DIR)/M5P.csv $(APP_DIR)/M5R.csv $(APP_DIR)/M5S.csv $(APP_DIR)/M5T.csv $(APP_DIR)/M5V.csv $(APP_DIR)/M5X.csv $(APP_DIR)/M6A.csv $(APP_DIR)/M6B.csv $(APP_DIR)/M6C.csv $(APP_DIR)/M6E.csv $(APP_DIR)/M6G.csv $(APP_DIR)/M6H.csv $(APP_DIR)/M6J.csv $(APP_DIR)/M6K.csv $(APP_DIR)/M6L.csv $(APP_DIR)/M6M.csv $(APP_DIR)/M6N.csv $(APP_DIR)/M6P.csv $(APP_DIR)/M6R.csv $(APP_DIR)/M6S.csv $(APP_DIR)/M7A.csv $(APP_DIR)/M8V.csv $(APP_DIR)/M8W.csv $(APP_DIR)/M8X.csv $(APP_DIR)/M8Y.csv $(APP_DIR)/M8Z.csv $(APP_DIR)/M9A.csv $(APP_DIR)/M9B.csv $(APP_DIR)/M9C.csv $(APP_DIR)/M9L.csv $(APP_DIR)/M9M.csv $(APP_DIR)/M9N.csv $(APP_DIR)/M9P.csv $(APP_DIR)/M9R.csv $(APP_DIR)/M9V.csv $(APP_DIR)/M9W.csv

all: $(APP_DIR)/fsas.json $(APP_DIR)/all.csv $(FSA_FILES)

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
	{ echo "CFSAUID,,Population,,"; cat $(DATA_DIR)/tmp; } > $@

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

$(APP_DIR)/fsas.json: $(DATA_DIR)/fsas.geojson $(DATA_DIR)/population.csv $(DATA_DIR)/sr_totals.csv
	topojson \
	 -e $(DATA_DIR)/population.csv \
	 -e $(DATA_DIR)/sr_totals.csv \
	 --id-property CFSAUID \
	 -p Population=+Population \
	 -p Total=+total \
	 -o $@ \
	 -- $<

$(DATA_DIR)/sr_totals.csv: $(DATA_DIR)/sr.db
	echo "CFSAUID,total" > $@
	sqlite3 $(DATA_DIR)/sr.db -csv "SELECT location, COUNT(location) from sr where location is not null GROUP BY location" >> $@

$(APP_DIR)/all.csv: $(DATA_DIR)/sr.db
	echo "date,value,lower,upper" > $@
	sqlite3 $(DATA_DIR)/sr.db -csv "select strftime('%Y-%m',date) || '-01' as _date, count(date),0,0 from sr where location is not null group by _date" >> $@
	Rscript forecast.R $@ tmp
	cat tmp >> $@
	rm tmp

$(APP_DIR)/%.csv: $(DATA_DIR)/sr.db
	echo "date,value,lower,upper" > $@
	sqlite3 $(DATA_DIR)/sr.db -csv "select strftime('%Y-%m',date) || '-01' as _date, count(date),0,0 from sr where location='$(*F)' group by _date" >> $@
	Rscript forecast.R $@ tmp
	cat tmp >> $@
	rm tmp

clean:
	rm -rf $(DATA_DIR)/* $(APP_DIR)/fsas.json
