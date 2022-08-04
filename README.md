<html>
<p align="center">
  <img src="https://user-images.githubusercontent.com/31255434/182289305-4cc620e3-86ae-480f-9b61-6ca83283caa5.jpg" alt="Latch Verified" width="100">
</p>

<h1 align="center">
  Differential Expression
</h1>

<p align="center">
<strong>
Latch Verified
</strong>
</p>

<p align="center">
  Reveal statistically significant genes and transcripts from count matrices.
</p>

<p align="center">
  <a href="https://github.com/latch-verified/diff-exp/releases/latest">
    <img src="https://img.shields.io/github/release/latch-verified/diff-exp.svg" alt="Current Release" />
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/LICENSE-MIT-brightgreen.svg" alt="License" />
  </a>
  <img src="https://img.shields.io/github/commit-activity/w/latch-verified/diff-exp.svg?style=plastic" alt="Commit Activity" />
  <img src="https://img.shields.io/github/commits-since/latch-verified/diff-exp/latest.svg?style=plastic" alt="Commits since Last Release" />
</p>

<h3 align="center">
  <a href="https://console.latch.bio/se/deseq2">Hosted Interface</a>
  <span> · </span>
  <a href="https://docs.latch.bio">SDK Documentation</a>
  <span> · </span>
  <a href="https://join.slack.com/t/latchbiosdk/shared_invite/zt-193ibmedi-WB6mBu2GJ2WejUHhxMOuwg">Slack Community</a>
</h3>

</html>


Using RNA-seq to generate matrices of transcript and gene abundances has become
a staple technique for measuring cell state.[^1] Often it is desirable to use
statistical techniques to compare these count matrices across different
experimental conditions to reveal genes that change.[^2]

A software benchmark conducted by Costa Silva et. al revealed
[DESeq2](https://bioconductor.org/packages/release/bioc/html/DESeq2.html) to be
the most performant. For each of a list of tools, reported significant genes were
compared against ground-truth genes derived from qRT-PCR, and DESeq2
consistently showed the highest
[sensitivity](https://en.wikipedia.org/wiki/Sensitivity_and_specificity) (TPR) and [accuracy](https://en.wikipedia.org/wiki/Accuracy_and_precision).

![table](https://user-images.githubusercontent.com/31255434/182885594-e5986335-0f3a-484d-969a-306b02aa9d82.png)


[^1]: Stark, Rory; Grzelak, Marta; Hadfield, James (2019). RNA sequencing: the teenage years. Nature Reviews Genetics, (), –. doi:10.1038/s41576-019-0150-2 
[^2]: Costa-Silva J, Domingues D, Lopes FM (2017) RNA-Seq differential expression analysis: An extended review and a software tool. PLoS ONE 12(12): e0190152. https://doi.org/10.1371/journal.pone.0190152
