///|
/// Normalize, validate, deduplicate, and sort metadata facts from analyzed files.
fn aggregate_metadata_findings(
  inspections : Array[@model.FileInspection],
  diagnostics : Array[@model.Diagnostic],
) -> Array[@model.MetadataFinding] {
  let findings : Array[@model.MetadataFinding] = []
  for inspection in inspections {
    if inspection.analyzed {
      for finding in inspection.metadata_findings {
        let is_timestamp = finding.category.to_string() ==
          @model.MetadataCategory::PointTimestamp.to_string()
        let valid_ordinal = finding.item_ordinal >= 1 &&
          (!is_timestamp || finding.item_ordinal <= inspection.point_count)
        let valid_count = finding.occurrence_count > 0 ||
          (is_timestamp && finding.occurrence_count == 0)
        if valid_ordinal && valid_count {
          findings.push(
            @model.make_metadata_finding(
              inspection.source_path,
              finding.category,
              finding.item_ordinal,
              finding.occurrence_count,
            ),
          )
        } else {
          diagnostics.push(
            invalid_metadata_finding_diagnostic(inspection.source_path),
          )
        }
      }
    }
  }
  findings.sort_by(compare_metadata_findings)

  let unique_findings : Array[@model.MetadataFinding] = []
  for finding in findings {
    let last_index = unique_findings.length() - 1
    if last_index >= 0 &&
      same_metadata_identity(unique_findings[last_index], finding) {
      if finding.occurrence_count > unique_findings[last_index].occurrence_count {
        unique_findings[last_index] = finding
      }
    } else {
      unique_findings.push(finding)
    }
  }
  unique_findings
}

///|
fn same_metadata_identity(
  left : @model.MetadataFinding,
  right : @model.MetadataFinding,
) -> Bool {
  left.source_path == right.source_path &&
  left.category.to_string() == right.category.to_string() &&
  left.item_ordinal == right.item_ordinal
}

///|
fn compare_metadata_findings(
  left : @model.MetadataFinding,
  right : @model.MetadataFinding,
) -> Int32 {
  let path_order = left.source_path.compare(right.source_path)
  if path_order != 0 {
    return path_order
  }
  let category_order = left.category
    .to_string()
    .compare(right.category.to_string())
  if category_order != 0 {
    return category_order
  }
  if left.item_ordinal != right.item_ordinal {
    return left.item_ordinal.compare(right.item_ordinal)
  }
  left.occurrence_count.compare(right.occurrence_count)
}

///|
fn invalid_metadata_finding_diagnostic(
  source_path : String,
) -> @model.Diagnostic {
  @model.Diagnostic::new(
    @model.code_invalid_metadata_finding,
    @model.Warning,
    source_path,
    "an invalid metadata coverage fact was omitted",
  )
}
