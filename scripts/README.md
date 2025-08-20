# Issue Statistics Scripts

This directory contains scripts for analyzing and reporting on GitHub Issues in the VS Marketplace repository.

## Scripts

### `generate-issue-report.sh`

Generates a comprehensive report with statistics on open issues, including:

- **Issue Types**: Bug, Feature Request, Documentation, Questions, etc.
- **Issue Duration**: Categorized by age (< 1 week, 1 week - 1 month, 1-6 months, 6 months - 1 year, > 1 year)
- **Priority Distribution**: Issues by priority levels (Priority:0, Priority:1, Priority:2)
- **Assignment Status**: Assigned vs unassigned issues

### `generate-sample-report.sh`

Generates a sample report with realistic data to demonstrate the report format and structure without requiring GitHub API access. Useful for testing and understanding the expected output.

#### Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- `jq` command-line JSON processor
- Bash shell

#### Usage

```bash
# Generate report for default repository (microsoft/vsmarketplace)
./scripts/generate-issue-report.sh

# Generate report for a different repository
REPO="owner/repository" ./scripts/generate-issue-report.sh

# Specify custom output file
OUTPUT_FILE="my-report.md" ./scripts/generate-issue-report.sh

# Combine options
REPO="microsoft/vsmarketplace" OUTPUT_FILE="monthly-report.md" ./scripts/generate-issue-report.sh
```

#### Output

The script generates a markdown report file (`issue-report.md` by default) containing:

1. **Summary Statistics** - Overview of all issues with counts and percentages
2. **Issue Distribution by Type** - Breakdown of bugs, features, documentation, etc.
3. **Issue Age Distribution** - How long issues have been open
4. **Priority Distribution** - Current priority assignments
5. **Assignment Status** - Assigned vs unassigned issues
6. **Key Insights** - Analysis of long-running issues and areas needing attention

#### Environment Variables

- `REPO`: Target repository (default: `microsoft/vsmarketplace`)
- `OUTPUT_FILE`: Output markdown file name (default: `issue-report.md`)

#### Examples

```bash
# Basic usage
./scripts/generate-issue-report.sh

# Generate sample report for testing/demo
./scripts/generate-sample-report.sh

# Weekly report
OUTPUT_FILE="reports/weekly-$(date +%Y-%m-%d).md" ./scripts/generate-issue-report.sh

# Different repository
REPO="microsoft/vscode" ./scripts/generate-issue-report.sh
```

#### Notes

- The script requires GitHub CLI authentication (`gh auth login`)
- Large repositories may take longer to process
- The script fetches up to 1000 open issues (GitHub API limit)
- Duration calculations are based on issue creation date vs current date