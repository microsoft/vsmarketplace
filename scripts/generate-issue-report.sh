#!/bin/bash

# Generate Issue Statistics Report
# This script analyzes open issues in the microsoft/vsmarketplace repository
# and generates a comprehensive report with statistics on types and durations.

set -euo pipefail

REPO="${REPO:-microsoft/vsmarketplace}"
OUTPUT_FILE="${OUTPUT_FILE:-issue-report.md}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Generating Issue Statistics Report for ${REPO}${NC}"
echo "📄 Output file: ${OUTPUT_FILE}"
echo ""

# Check dependencies
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI (gh) is not installed or not in PATH${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ Error: jq is not installed${NC}"
    exit 1
fi

# Verify GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI is not authenticated${NC}"
    echo "Please run: gh auth login"
    echo ""
    echo -e "${YELLOW}💡 Alternative: Run the sample report generator to see the expected output format:${NC}"
    echo "   ./scripts/generate-sample-report.sh"
    exit 1
fi

echo -e "${GREEN}✅ Dependencies verified${NC}"

# Get current date for calculations
current_date=$(date +%s)
one_week_ago=$((current_date - 604800))      # 7 days * 24 hours * 60 minutes * 60 seconds
one_month_ago=$((current_date - 2592000))    # 30 days * 24 hours * 60 minutes * 60 seconds
six_months_ago=$((current_date - 15552000))  # 180 days * 24 hours * 60 minutes * 60 seconds
one_year_ago=$((current_date - 31536000))    # 365 days * 24 hours * 60 minutes * 60 seconds

echo -e "${YELLOW}📊 Fetching open issues...${NC}"

# Fetch all open issues with required fields
issues_json=$(gh issue list -R "$REPO" --state open --limit 1000 --json number,title,labels,createdAt,url,assignees)

if [[ -z "$issues_json" || "$issues_json" == "[]" ]]; then
    echo -e "${RED}❌ No open issues found or unable to fetch issues${NC}"
    exit 1
fi

total_issues=$(echo "$issues_json" | jq 'length')
echo -e "${GREEN}✅ Found ${total_issues} open issues${NC}"

# Initialize counters
declare -A type_counts
declare -A duration_counts
declare -A priority_counts

type_counts["Bug"]=0
type_counts["Feature"]=0
type_counts["Documentation"]=0
type_counts["Question"]=0
type_counts["Enhancement"]=0
type_counts["Other"]=0
type_counts["Untyped"]=0

duration_counts["Less than 1 week"]=0
duration_counts["1 week to 1 month"]=0
duration_counts["1 to 6 months"]=0
duration_counts["6 months to 1 year"]=0
duration_counts["More than 1 year"]=0

priority_counts["Priority:0"]=0
priority_counts["Priority:1"]=0
priority_counts["Priority:2"]=0
priority_counts["No Priority"]=0

assignee_count=0
unassigned_count=0

echo -e "${YELLOW}🔍 Analyzing issues...${NC}"

# Process each issue
while IFS= read -r issue; do
    # Get issue creation date
    created_at=$(echo "$issue" | jq -r '.createdAt')
    created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" +%s 2>/dev/null || echo "0")
    
    # Calculate duration category
    if [[ $created_timestamp -gt $one_week_ago ]]; then
        ((duration_counts["Less than 1 week"]++))
    elif [[ $created_timestamp -gt $one_month_ago ]]; then
        ((duration_counts["1 week to 1 month"]++))
    elif [[ $created_timestamp -gt $six_months_ago ]]; then
        ((duration_counts["1 to 6 months"]++))
    elif [[ $created_timestamp -gt $one_year_ago ]]; then
        ((duration_counts["6 months to 1 year"]++))
    else
        ((duration_counts["More than 1 year"]++))
    fi
    
    # Get labels
    labels=$(echo "$issue" | jq -r '.labels[].name' | tr '\n' ' ')
    
    # Determine issue type
    issue_typed=false
    if echo "$labels" | grep -q "Type:Bug\|bug"; then
        ((type_counts["Bug"]++))
        issue_typed=true
    fi
    if echo "$labels" | grep -q "Type:Feature\|feature\|enhancement"; then
        ((type_counts["Feature"]++))
        issue_typed=true
    fi
    if echo "$labels" | grep -q "documentation\|docs"; then
        ((type_counts["Documentation"]++))
        issue_typed=true
    fi
    if echo "$labels" | grep -q "question"; then
        ((type_counts["Question"]++))
        issue_typed=true
    fi
    if echo "$labels" | grep -q "enhancement" && ! echo "$labels" | grep -q "Type:Feature"; then
        ((type_counts["Enhancement"]++))
        issue_typed=true
    fi
    
    if [[ "$issue_typed" == "false" ]]; then
        if [[ -n "$labels" ]]; then
            ((type_counts["Other"]++))
        else
            ((type_counts["Untyped"]++))
        fi
    fi
    
    # Check priority
    priority_found=false
    if echo "$labels" | grep -q "Priority:0"; then
        ((priority_counts["Priority:0"]++))
        priority_found=true
    elif echo "$labels" | grep -q "Priority:1"; then
        ((priority_counts["Priority:1"]++))
        priority_found=true
    elif echo "$labels" | grep -q "Priority:2"; then
        ((priority_counts["Priority:2"]++))
        priority_found=true
    fi
    
    if [[ "$priority_found" == "false" ]]; then
        ((priority_counts["No Priority"]++))
    fi
    
    # Check assignees
    assignees=$(echo "$issue" | jq -r '.assignees[]?.login' 2>/dev/null || echo "")
    if [[ -n "$assignees" ]]; then
        ((assignee_count++))
    else
        ((unassigned_count++))
    fi
    
done < <(echo "$issues_json" | jq -c '.[]')

echo -e "${GREEN}✅ Analysis complete${NC}"

# Generate the report
echo -e "${YELLOW}📝 Generating report...${NC}"

cat > "$OUTPUT_FILE" << EOF
# VS Marketplace Open Issues Report

Generated on: $(date)
Repository: ${REPO}
Total Open Issues: ${total_issues}

## Summary Statistics

### Issue Distribution by Type

| Type | Count | Percentage |
|------|-------|------------|
| Bug | ${type_counts["Bug"]} | $(( type_counts["Bug"] * 100 / total_issues ))% |
| Feature Request | ${type_counts["Feature"]} | $(( type_counts["Feature"] * 100 / total_issues ))% |
| Documentation | ${type_counts["Documentation"]} | $(( type_counts["Documentation"] * 100 / total_issues ))% |
| Question | ${type_counts["Question"]} | $(( type_counts["Question"] * 100 / total_issues ))% |
| Enhancement | ${type_counts["Enhancement"]} | $(( type_counts["Enhancement"] * 100 / total_issues ))% |
| Other | ${type_counts["Other"]} | $(( type_counts["Other"] * 100 / total_issues ))% |
| Untyped | ${type_counts["Untyped"]} | $(( type_counts["Untyped"] * 100 / total_issues ))% |

### Issue Age Distribution

| Duration | Count | Percentage |
|----------|-------|------------|
| Less than 1 week | ${duration_counts["Less than 1 week"]} | $(( duration_counts["Less than 1 week"] * 100 / total_issues ))% |
| 1 week to 1 month | ${duration_counts["1 week to 1 month"]} | $(( duration_counts["1 week to 1 month"] * 100 / total_issues ))% |
| 1 to 6 months | ${duration_counts["1 to 6 months"]} | $(( duration_counts["1 to 6 months"] * 100 / total_issues ))% |
| 6 months to 1 year | ${duration_counts["6 months to 1 year"]} | $(( duration_counts["6 months to 1 year"] * 100 / total_issues ))% |
| More than 1 year | ${duration_counts["More than 1 year"]} | $(( duration_counts["More than 1 year"] * 100 / total_issues ))% |

### Priority Distribution

| Priority | Count | Percentage |
|----------|-------|------------|
| Priority:0 (Critical) | ${priority_counts["Priority:0"]} | $(( priority_counts["Priority:0"] * 100 / total_issues ))% |
| Priority:1 (High) | ${priority_counts["Priority:1"]} | $(( priority_counts["Priority:1"] * 100 / total_issues ))% |
| Priority:2 (Normal) | ${priority_counts["Priority:2"]} | $(( priority_counts["Priority:2"] * 100 / total_issues ))% |
| No Priority | ${priority_counts["No Priority"]} | $(( priority_counts["No Priority"] * 100 / total_issues ))% |

### Assignment Status

| Status | Count | Percentage |
|--------|-------|------------|
| Assigned | ${assignee_count} | $(( assignee_count * 100 / total_issues ))% |
| Unassigned | ${unassigned_count} | $(( unassigned_count * 100 / total_issues ))% |

## Key Insights

### Long-running Issues
- **Issues open for more than 6 months**: $(( duration_counts["6 months to 1 year"] + duration_counts["More than 1 year"] )) issues ($(( (duration_counts["6 months to 1 year"] + duration_counts["More than 1 year"]) * 100 / total_issues ))%)
- **Issues open for more than 1 year**: ${duration_counts["More than 1 year"]} issues ($(( duration_counts["More than 1 year"] * 100 / total_issues ))%)

### Type Analysis
- **Bug vs Feature ratio**: ${type_counts["Bug"]} bugs vs ${type_counts["Feature"]} feature requests
- **Untyped issues**: ${type_counts["Untyped"]} issues need type classification

### Priority Analysis
- **High priority issues** (Priority:0 + Priority:1): $(( priority_counts["Priority:0"] + priority_counts["Priority:1"] )) issues
- **Issues without priority**: ${priority_counts["No Priority"]} issues need prioritization

---

*Report generated by VS Marketplace Issue Analytics*
*For more information, see: https://github.com/${REPO}*
EOF

echo -e "${GREEN}✅ Report generated: ${OUTPUT_FILE}${NC}"
echo ""
echo -e "${BLUE}📋 Quick Summary:${NC}"
echo "  Total Issues: ${total_issues}"
echo "  Bugs: ${type_counts["Bug"]} | Features: ${type_counts["Feature"]} | Untyped: ${type_counts["Untyped"]}"
echo "  >6 months old: $(( duration_counts["6 months to 1 year"] + duration_counts["More than 1 year"] ))"
echo "  >1 year old: ${duration_counts["More than 1 year"]}"
echo "  Unassigned: ${unassigned_count}"
echo ""
echo -e "${GREEN}🎉 Done! Check ${OUTPUT_FILE} for the full report.${NC}"