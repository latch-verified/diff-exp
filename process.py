import csv
import json
from pathlib import Path

with Path("res/Results.csv").open("r") as f:
    r = csv.reader(f)
    data = []
    for x in r:
        if x[0] == "":
            continue

        if x[5] == "NA":
            continue

        data.append({"gene_id": x[0], "pvalue": float(x[5])})

    data.sort(key=lambda x: -x["pvalue"])
    top_ids = set(x["gene_id"] for x in data[:20])

with Path("counts.tsv").open("r") as f:
    r = csv.reader(f, delimiter="\t")

    samples = []
    genes = []
    data = []
    for x in r:
        if x[0] == "gene_id":
            samples = x[2:]
            continue

        if x[0] in top_ids:
            genes.append(x[1])
            data.append([float(v) for v in x[2:]])

print(json.dumps({"genes": genes, "samples": samples, "data": data}))
