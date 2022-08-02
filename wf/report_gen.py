import re
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Set

from wf.util import warn, warning


@dataclass
class ExperimentResult:
    id: str
    csv_path: Path
    qc_path: str
    ma_path: str
    volcano_path: str


full_name_regex = re.compile(r"^(?P<l1>.+) vs (?P<l2>.+) \((?P<col>.+)\)")


def generate_report():
    print("Generating the report")
    options: List[ExperimentResult] = []

    level_options: Dict[str, Dict[str, Set[str]]] = {}

    for path in Path("./res/Data/Contrast").iterdir():
        try:
            full = str(path.with_suffix("").name)

            matches = full_name_regex.match(full)
            if matches is None:
                raise RuntimeError(f"Could not match full name '{full}'")

            l1 = matches.group("l1")
            l2 = matches.group("l2")
            col = matches.group("col")

            col_options = level_options.setdefault(col, {})
            l1_options = col_options.setdefault(l1, set())

            l1_options.add(l2)

            id = f"{col}_{l1}_{l2}"
            options += [
                ExperimentResult(
                    id=id,
                    csv_path=path,
                    # todo(maximsmol): make interactive
                    qc_path=f"./Plots/QC/Variance P-Value/{full}.png",
                    ma_path=f"./res/Plots/Contrast/{full}/MA.html",
                    volcano_path=f"./res/Plots/Contrast/{full}/Volcano.html",
                )
            ]
        except:
            traceback.print_exc()
            warn(
                f"Failed to parse contrast data for {path.name}",
                "Skipping plot generation for this contrast",
                sep="\n",
            )
            warning(
                {
                    "title": f"Failed to parse contrast data for {path.name}",
                    "body": "Skipping plot generation for this contrast",
                }
            )

    return {
        col: {l1: sorted(level_options[col][l1]) for l1 in level_options[col]}
        for col in level_options
    }
