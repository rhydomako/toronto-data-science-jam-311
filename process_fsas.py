import pandas as pd
import numpy as np
import sqlite3
import sys

if __name__=='__main__':
    db    = sys.argv[1]
    output = sys.argv[2]
    ts_output = sys.argv[3]

    conn = sqlite3.connect(db)
    data = pd.read_sql("SELECT type, location, 1 AS count FROM sr WHERE location IS NOT NULL", conn)
    pivot_table = pd.pivot_table(data,
                                 values=['count'],
                                 index=['location'],
                                 columns=['type'],
                                 aggfunc=np.sum,
                                 fill_value=0,
                                 margins=True)
    pivot_table.columns = pivot_table.columns.get_level_values(1)
    pivot_table.reset_index().to_csv(output, index=False, encoding='utf-8')


    ts_data = pd.read_sql("SELECT strftime('%Y-%m',date) || '-01' as _date, type, count(date) AS count FROM sr WHERE location IS NOT NULL group by _date, type", conn)
    ts_pivot_table = pd.pivot_table(ts_data,
                             values=['count'],
                             index=['_date'],
                             columns=['type'],
                             aggfunc=np.sum,
                             fill_value=0,
                             margins=True)
    ts_pivot_table.columns = ts_pivot_table.columns.get_level_values(1)
    ts_pivot_table = ts_pivot_table[ts_pivot_table.index != 'All']
    ts_pivot_table.reset_index().to_csv(ts_output, index=False, encoding='utf-8')
