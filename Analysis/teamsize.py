import pandas as pd
import csv
import sqlalchemy
from sqlalchemy import create_engine
from sqlalchemy import text
import os
os.chdir("G:/SED")
sm = create_engine("mysql+mysqldb://[username]:[password]@localhost:3306/starmetrics")
csvfile = open("teamsize.csv", "wb")
writer = csv.writer(csvfile)
data = pd.read_csv("for_ahmad.csv")
data["startDate"] = data["start_year"].map(str) + "-" + data["start_month"].map(str) + "-01"
data["endDate"] = data["end_year"].map(str) + "-" + data["end_month"].map(str) + "-01"
writer.writerow(["year", "count"] + data.columns.tolist())
for index, row in data.iterrows():
	query = 'SELECT * FROM starmetrics.employee where periodstartdate >= "' + row[9] + '" and periodenddate <= "' +row[10] + '" and uniqueawardnumber = "' + row[3] + '" and university = "' + row[2]+ '" and recipientaccountnumber = "' + row[4] + '"'
	temp = pd.read_sql(query, sm)
	years = set(temp["year"])
	for year in years:
		temp2 = temp.loc[temp.year == year,:]
		if(str(row[1]) in temp2["employeeid"].tolist()):
			count = len(set(temp2["employeeid"])) - 1
		else:
			count = -1
		output = [year, count] + row.tolist()
		writer.writerow(output)
csvfile.close()
