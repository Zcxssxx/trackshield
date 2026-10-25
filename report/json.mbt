///|
/// Render an audit report as compact deterministic JSON.
pub fn render_json(report : @model.AuditReport) -> String {
  let locations = report.repeated_locations.copy()
  locations.sort_by((left, right) => left.id.compare(right.id))
  let metadata = report.metadata_findings.copy()
  metadata.sort_by(compare_metadata_findings)
  let diagnostics = report.diagnostics.copy()
  diagnostics.sort_by(compare_diagnostics)

  let output = StringBuilder(size_hint=512)
  output.write_string("{\"options\":{")
  output.write_string("\"radius_m\":")
  output.write_string(report.options.radius_m.to_string())
  output.write_string(",\"min_distinct_files\":")
  output.write_string(report.options.min_distinct_files.to_string())
  output.write_string(",\"include_coordinates\":")
  output.write_string(report.options.include_coordinates.to_string())
  output.write_string("},\"repeated_locations\":[")
  for index, location in locations {
    if index > 0 {
      output.write_char(',')
    }
    write_location_json(output, location, report.options.include_coordinates)
  }
  output.write_string("],\"metadata_findings\":[")
  for index, finding in metadata {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"source_path\":")
    output.write_string(json_string(finding.source_path))
    output.write_string(",\"category\":")
    output.write_string(json_string(finding.category.to_string()))
    output.write_string(",\"item_ordinal\":")
    output.write_string(finding.item_ordinal.to_string())
    output.write_string(",\"occurrence_count\":")
    output.write_string(finding.occurrence_count.to_string())
    output.write_char('}')
  }
  output.write_string("],\"diagnostics\":[")
  for index, diagnostic in diagnostics {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"code\":")
    output.write_string(json_string(diagnostic.code))
    output.write_string(",\"severity\":")
    output.write_string(json_string(diagnostic.severity.to_string()))
    output.write_string(",\"path\":")
    output.write_string(json_string(diagnostic.path))
    output.write_string(",\"message\":")
    output.write_string(json_string(diagnostic.message))
    output.write_char('}')
  }
  output.write_string("]}")
  output.to_string()
}

///|
fn write_location_json(
  output : StringBuilder,
  location : @model.RepeatedLocation,
  include_coordinates : Bool,
) -> Unit {
  output.write_string("{\"id\":")
  output.write_string(json_string(location.id))
  output.write_string(",\"distinct_file_count\":")
  output.write_string(location.distinct_file_count.to_string())
  output.write_string(",\"distinct_track_count\":")
  output.write_string(location.distinct_track_count.to_string())
  output.write_string(",\"evidence\":[")
  let evidence = location.evidence.copy()
  evidence.sort_by(compare_evidence)
  for index, item in evidence {
    if index > 0 {
      output.write_char(',')
    }
    output.write_string("{\"source_path\":")
    output.write_string(json_string(item.source_path))
    output.write_string(",\"track_ordinal\":")
    output.write_string(item.track_ordinal.to_string())
    output.write_string(",\"kind\":")
    output.write_string(json_string(item.kind.to_string()))
    output.write_string(",\"observation_index\":")
    output.write_string(item.observation_index.to_string())
    output.write_char('}')
  }
  output.write_string("],\"center\":")
  if include_coordinates {
    match location.center {
      Some(center) => {
        output.write_string("{\"latitude\":")
        output.write_string(center.latitude.to_string())
        output.write_string(",\"longitude\":")
        output.write_string(center.longitude.to_string())
        output.write_char('}')
      }
      None => output.write_string("null")
    }
  } else {
    output.write_string("null")
  }
  output.write_string(",\"max_distance_from_center_m\":")
  match location.max_distance_from_center_m {
    Some(distance) => output.write_string(distance.to_string())
    None => output.write_string("null")
  }
  output.write_string(",\"wide_component\":")
  output.write_string(location.wide_component.to_string())
  output.write_char('}')
}

///|
fn json_string(value : String) -> String {
  @json.to_json(value).stringify()
}

///|
fn compare_evidence(
  left : @model.EndpointEvidence,
  right : @model.EndpointEvidence,
) -> Int32 {
  let path_order = left.source_path.compare(right.source_path)
  if path_order != 0 {
    return path_order
  }
  if left.track_ordinal != right.track_ordinal {
    return left.track_ordinal.compare(right.track_ordinal)
  }
  let kind_order = left.kind.to_string().compare(right.kind.to_string())
  if kind_order != 0 {
    return kind_order
  }
  left.observation_index.compare(right.observation_index)
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
fn compare_diagnostics(
  left : @model.Diagnostic,
  right : @model.Diagnostic,
) -> Int32 {
  let path_order = left.path.compare(right.path)
  if path_order != 0 {
    return path_order
  }
  let code_order = left.code.compare(right.code)
  if code_order != 0 {
    return code_order
  }
  let severity_order = left.severity
    .to_string()
    .compare(right.severity.to_string())
  if severity_order != 0 {
    return severity_order
  }
  left.message.compare(right.message)
}
