# Priority Labeler Workflow Diagram

This diagram shows the flow of the `prioritize-by-reactions.yaml` GitHub Action workflow.

![Flowchart showing the different steps of the prioritize-by-reactions.yaml steps](prioritizeDetailFlowChart.png)

## Simplified Overview

![A simplified flowchart for the 4 main steps of prioritize-by-reactions.yaml](prioritizeSimpleFlowChart.png)

## Workflow Logic Summary

### Priority Assignment Rules:

**For Bug Issues (`Type:Bug`):**
- 10+ reactions → `Priority:0` (Highest)
- 5-9 reactions → `Priority:1` (Medium)
- 0-4 reactions → `Priority:2` (Low)

**For Feature Requests (`Type:Feature`):**
- 25+ reactions → `Priority:1` (Medium)
- 0-24 reactions → `Priority:2` (Low)

### Safety Features:
- Only processes issues with `Type:Bug` or `Type:Feature` labels
- Only modifies priority labels that were previously set by `github-actions[bot]`
- Preserves manually-set priority labels
- Gracefully handles API errors by skipping problematic issues
