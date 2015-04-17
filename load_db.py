import sqlite3
import xlrd
import sys
import requests
import time


if __name__=='__main__':
    db    = sys.argv[1]
    files = sys.argv[2:]

    conn = sqlite3.connect(db)
    c = conn.cursor()

    for f in files:
        print "Loading [{}]".format(f)
        workbook = xlrd.open_workbook(f)
        
        for sheet in workbook.sheets():
            for row in range(1, sheet.nrows):
                data = sheet.row(row)
                date         = xlrd.xldate.xldate_as_datetime(data[0].value, workbook.datemode)
                raw_location = data[1].value
                location     = None
                type         = data[2].value

                if raw_location[0] == 'M' and len(raw_location) == 3: 
                    location = raw_location

                c.execute("INSERT INTO sr VALUES(?,?,?,?)",(date,raw_location,location,type))

    conn.commit()
    conn.close()
