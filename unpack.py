from pathlib import Path
import json

out_p = Path("Report.deseqreport.out")
if out_p.exists():
    raise RuntimeError("Refusing to override output")

blob = Path("./Report.deseqreport").read_bytes()
cur = 0

l = int.from_bytes(blob[cur : cur + 4], byteorder="little", signed=False)
cur += 4

json_blob = blob[cur : cur + l]
cur += l

data = json.loads(json_blob.decode())

rename_map = {
    "_dds": "dds.rds",
    "sample_corr": "Sample Correlation.html",
    "counts_heatmap": "Counts Heatmap.html",
    "size_factor_qc": "Size Factor QC.html",
}

for edata in data["embedded_data_order"]:
    assert isinstance(edata, str)

    size = data["embedded_data_sizes"][edata]
    print(f"{edata}: {size}")

    out_name = rename_map.get(edata, edata)

    cur_p = out_p / out_name
    if cur_p.parent.name == "pca":
        cur_p = cur_p.with_suffix(".html")

    cur_p.parent.mkdir(parents=True, exist_ok=True)
    cur_p.write_bytes(blob[cur : cur + size])
    cur += size
