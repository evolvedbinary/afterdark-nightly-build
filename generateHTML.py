from os import walk
import os, re, sys, subprocess
from datetime import datetime

# fetch directory
location = sys.argv[1]
exist_git_clone = sys.argv[2]

# find all files
existFiles = []
for (dirpath, dirnames, filenames) in walk(location):

    for filename in filenames:

        if "eXist-db" in filename and "SNAPSHOT" in filename:
            existFiles.append(filename)


# get hashes
buildLabelPattern = re.compile("eXist-db(?:-setup)?-[0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT\+([0-9]{12,14})\.(?:jar|dmg)")
buildLabels = set()
for name in existFiles:
    groups = buildLabelPattern.match(name).groups()
    buildLabels.add(groups[0])

# start writing table
f = open(location + "/table.html", "w")
f.write("<div>")
f.write("<table id=\"myTable\" class=\"tablesorter\">\n\
<thead> \n\
<tr> \n\
<th>Date</th> \n\
<th>Build Label</th> \n\
<th>Git Hash</th> \n\
<th>Downloads</th> \n\
<th>Size</th> \n\
</tr> \n\
</thead> \n\
<tbody>\n")

# iterate over hashes
fileExtPattern = re.compile(".+\.(jar|dmg)$")
for buildLabel in buildLabels:

    # group files per download
    types = {};
    maxSize = 0
    recentDate = ""
    for file in existFiles:
        if buildLabel in file:
            groups = fileExtPattern.match(file).groups()
            types[groups[0]] = file

            fileSize = os.path.getsize(location + "/" + file)
            if fileSize > maxSize:
                maxSize = fileSize

            changeDate = datetime.strptime(buildLabel, "%Y%m%d%H%M%S").strftime("%Y-%m-%d")
            if changeDate > recentDate:
                recentDate = changeDate

            gitBeforeDate =  datetime.strptime(buildLabel, "%Y%m%d%H%M%S").strftime("%Y-%m-%d %H:%M:%S")
            gitProcess = subprocess.Popen(["git", "rev-list", "-1", "--before=\"" + gitBeforeDate + "\"", "develop"], cwd=exist_git_clone, stdout=subprocess.PIPE)
            output = gitProcess.communicate()[0]
            gitHash = output.strip()[:7]


    f.write("<tr>\n")
    f.write("<td>" + changeDate + "</td>\n")
    f.write("<td>" + buildLabel + "</td>\n")
    f.write("<td><a href=\"https://github.com/eXist-db/exist/commit/" + gitHash + "\">" + gitHash + "</a></td>\n")
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
