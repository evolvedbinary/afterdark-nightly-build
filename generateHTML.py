from os import walk
import os, re, time, sys
from datetime import datetime

# fetch directory
location = sys.argv[1]

# find all files
existFiles = []
for (dirpath, dirnames, filenames) in walk(location):

    for filename in filenames:

        if "eXist" in filename:
            existFiles.append(filename)

# get hashes
revIdPattern = re.compile("eXist-db.*-develop-(.*)\....")
ids = set()
for name in existFiles:
    groups = revIdPattern.match(name).groups()
    ids.add(groups[0])

# start writing table
f = open(location + "/table.html", "w")
f.write("<div>")
f.write("<table id=\"myTable\" class=\"tablesorter\">\n\
<thead> \n\
<tr> \n\
<th>Date</th> \n\
<th>Hash</th> \n\
<th>Downloads</th> \n\
<th>Size</th> \n\
</tr> \n\
</thead> \n\
<tbody>\n")

# iterate over hashes
fileExtPattern = re.compile("eXist-db.*-develop-.*\.(...)")
for id in ids:

    # group files per download
    types = {};
    maxSize = 0
    recentDate = ""
    for file in existFiles:
        if id in file: 
            groups = fileExtPattern.match(file).groups()
            types[groups[0]] = file

            fileSize = os.path.getsize(location + "/" + file)
            if fileSize > maxSize:
                maxSize = fileSize

            changeDate = time.strftime("%Y-%m-%d", time.localtime(os.path.getmtime(location + "/" + file)))
            if changeDate > recentDate:
                recentDate = changeDate


    f.write("<tr>\n")
    f.write("<td>" + changeDate + "</td>\n")
    f.write("<td>" + id + "</td>\n")
    f.write("<td>")
    for type in types.keys():
        f.write("<a href=\"" + str(types.get(type)) + "\">" + type + "</a> \n")
    f.write("</td>\n")
    f.write("<td>" + ('%.1f' % (float(maxSize) / (1024 * 1024))) + 'MB' + "</td>\n")
    f.write("</tr>\n")

f.write("</tbody>\n</table>")
f.write("<script>$(function(){$(\"#myTable\").tablesorter({sortList : [[0,1]]}); }); </script>")
f.write("</div>")

f.close()
