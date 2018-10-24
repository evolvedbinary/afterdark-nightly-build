#!/usr/bin/env python3

from os import walk
import os, re, sys, subprocess
from datetime import datetime
import argparse

###
## Generates a HTML table of eXist-db dist artifacts
###

tmp_dir="/tmp/exist-nightly-build/dist"
default_build_dir = tmp_dir + "/source"
default_output_dir = tmp_dir + "/target"

# parse command line arguments
parser = argparse.ArgumentParser(description="Generate an index.html table of nightly builds")
parser.add_argument("-b", "--git-branch", default="develop", dest="git_branch", help="The git branch to use")
parser.add_argument("-u", "--github-repo-url", default="https://github.com/eXist-db/exist", dest="github_repo_url", help="Public URL of the GitHub repo")
parser.add_argument("-d", "--build-dir", default=default_build_dir, dest="build_dir", help="The directory containing the eXist-db build")
parser.add_argument("-o", "--output-dir", default=default_output_dir, dest="output_dir", help="The directory containing the built eXist-db artifacts")
parser.add_argument("-f", "--file-name", default="table.html", dest="filename", help="The name for the generated HTML file")
args = parser.parse_args()

print(f"""Generating {args.output_dir}/{args.filename}...""")

# find all files
existFiles = []
for (dirpath, dirnames, filenames) in walk(args.output_dir):

    for filename in filenames:

        if ("eXist-db" in filename or "exist" in filename) and "SNAPSHOT" in filename and ".sha256" not in filename:
            existFiles.append(filename)


# get hashes
buildLabelPattern = re.compile("(?:eXist-db|exist)(?:-setup)?-[0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT\+([0-9]{12,14})\.(?:jar|dmg|tar\.bz2|war)")
buildLabels = set()
for name in existFiles:
    groups = buildLabelPattern.match(name).groups()
    buildLabels.add(groups[0])

# start writing table
f = open(args.output_dir + "/" + args.filename, "w")
f.write("""<div>
    <table id="myTable" class="tablesorter">
        <thead>
            <tr>
                <th>Date</th>
                <th>Build Label</th>
                <th>Git Hash</th>
                <th>Downloads</th>
            </tr>
        </thead>
        <tbody>
        """)

# iterate over hashes
fileExtPattern = re.compile(".+\.(jar|dmg|tar\.bz2|war)$")
labelPattern = re.compile("(?:eXist-db|exist)(?:-setup)?-([0-9]+\.[0-9]+\.[0-9]+(?:-SNAPSHOT\+[0-9]{12})?)\.(?:jar|dmg|tar\.bz2|war)$")
for buildLabel in buildLabels:

    # group files per download
    types = {};
    recentDate = ""
    for file in existFiles:
        if buildLabel in file:
            groups = fileExtPattern.match(file).groups()
            types[groups[0]] = file

            changeDate = datetime.strptime(buildLabel, "%Y%m%d%H%M%S").strftime("%Y-%m-%d")
            if changeDate > recentDate:
                recentDate = changeDate

            gitBeforeDate =  datetime.strptime(buildLabel, "%Y%m%d%H%M%S").strftime("%Y-%m-%d %H:%M:%S")
            gitProcess = subprocess.run(["git", "rev-list", "-1", "--before=\"" + gitBeforeDate + "\"", args.git_branch], cwd=args.build_dir, stdout=subprocess.PIPE, encoding='utf-8', check=True)
            gitHash = gitProcess.stdout.strip()[:7]
            labelGroups = labelPattern.match(file).groups()
            label = labelGroups[0]


    f.write(f"""    <tr>
                <td>{changeDate}</td>
                <td>{label}</td>
                <td><a href="{args.github_repo_url}/commit/{gitHash}">{gitHash}</a></td>
                <td>
                    <ul>
                """)
    for type in types.keys():
        f.write(f"""        <li><a href="{str(types.get(type))}">{type}</a> ({('%.1f' % (float(os.path.getsize(args.output_dir + "/" + types.get(type))) / (1024 * 1024)))} MB) <a href="{str(types.get(type))}.sha256">SHA256</a></li>
                """)
        print(f"""Added {str(types.get(type))}""")
    f.write(f"""    </ul>
            </tr>
        </tbody>
    </table>
    """)
    f.write("""<script>$(function(){$("#myTable").tablesorter({sortList : [[0,1]]}); });</script>
</div>""")

f.close()

print("Done.")
