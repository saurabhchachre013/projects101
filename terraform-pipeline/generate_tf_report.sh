#!/bin/bash

PLAN_JSON="tfplan.json"
REPORT="terraform-report.md"

# -----------------------------
# Terraform Plan Summary
# -----------------------------

ADD=$(jq '[.resource_changes[].change.actions | select(. == ["create"])] | length' "$PLAN_JSON")

CHANGE=$(jq '[.resource_changes[].change.actions | select(. == ["update"])] | length' "$PLAN_JSON")

DESTROY=$(jq '[.resource_changes[].change.actions | select(. == ["delete"])] | length' "$PLAN_JSON")

REPLACE=$(jq '[.resource_changes[].change.actions | select((index("create") != null) and (index("delete") != null))] | length' "$PLAN_JSON")


# -----------------------------
# Create Report
# -----------------------------

echo "# Terraform Plan" > "$REPORT"

echo "" >> "$REPORT"
echo "Status: PASS" >> "$REPORT"

echo "" >> "$REPORT"

echo "## Summary" >> "$REPORT"

if [ "$DESTROY" -gt 0 ] || [ "$REPLACE" -gt 0 ]; then
    echo "" >> "$REPORT"
    echo "## Warnings" >> "$REPORT"
    echo "" >> "$REPORT"

    if [ "$DESTROY" -gt 0 ]; then
        echo "WARNING: $DESTROY resource(s) will be destroyed." >> "$REPORT"
    fi

    if [ "$REPLACE" -gt 0 ]; then
        echo "WARNING: $REPLACE resource(s) will be replaced." >> "$REPORT"
    fi
fi

echo "" >> "$REPORT"

echo "| Action | Count |" >> "$REPORT"
echo "|---|---:|" >> "$REPORT"
echo "| Add | $ADD |" >> "$REPORT"
echo "| Change | $CHANGE |" >> "$REPORT"
echo "| Destroy | $DESTROY |" >> "$REPORT"
echo "| Replace | $REPLACE |" >> "$REPORT"


# -----------------------------
# Change Details
# -----------------------------

echo "" >> "$REPORT"

echo "## Change Details" >> "$REPORT"

echo "" >> "$REPORT"

jq -r '
.resource_changes[] |
[
  "### \(.address)",
  "",
  "Action: \(.change.actions | join(", "))",
  (
    .change.after
    | to_entries
    | map(select(.value != null))
    | map("\(.key) = \(.value)")
    | join("\n")
  ),
  ""
] |
join("\n")
' "$PLAN_JSON" >> "$REPORT"


# -----------------------------
# Finish
# -----------------------------

echo "Terraform report generated: $REPORT"