from latch.types import LatchFile

from wf import deseq2_wf

deseq2_wf(
    raw_count_table=LatchFile("s3://latch-public/welcome/deseq2/ibd/ibd_counts.csv"),
    raw_count_tables=[],
    report_name="(Knyazev, 2021) Inflammatory Bowel Diseases DESeq2 Report",
    conditions_source="table",
    conditions_table=LatchFile("s3://latch-public/welcome/deseq2/ibd/ibd_design.csv"),
    design_matrix_sample_id_column="Sample",
    design_formula=[["Condition", "explanatory"]],
),
