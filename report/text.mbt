///|
/// Render an audit report as stable human-readable text.
pub fn render_text(report : @model.AuditReport) -> String {
  let locations = report.repeated_locations.copy()
  locations.sort_by((left, right) => left.id.compare(right.id))
  let metadata = report.metadata_findings.copy()
  metadata.sort_by(compare_metadata_findings)
  let diagnostics = report.diagnostics.copy()
  diagnostics.sort_by(compare_diagnostics)

  let output = StringBuilder(size_hint=512)
  output.write_string("TrackShield privacy audit\n\nEndpoint radius: ")
  output.write_string(report.options.radius_m.to_string())
  output.write_string(" m\nMinimum distinct files: ")
  output.write_string(report.options.min_distinct_files.to_string())
  output.write_string("\nCoordinates: ")
  output.write_string(
    if report.options.include_coordinates {
      "explicit opt-in"
    } else {
      "hidden"
    },
  )
  output.write_string("\n\nRepeated endpoint clues\n")
  if locations.is_empty() {
    output.write_string("- none\n")
  } else {
    for location in locations {
      output.write_string("- ")
      output.write_string(location.id)
      output.write_string(": ")
      output.write_string(location.distinct_file_count.to_string())
      output.write_string(" files, ")
      output.write_string(location.distinct_track_count.to_string())
      output.write_string(" tracks\n")
      let evidence = location.evidence.copy()
      evidence.sort_by(compare_evidence)
      for item in evidence {
        output.write_string("  - ")
        output.write_string(json_string(item.source_path))
        output.write_string(", track ")
        output.write_string(item.track_ordinal.to_string())
        output.write_char(' ')
        output.write_string(item.kind.to_string())
        output.write_string(" endpoint (observation ")
        output.write_string(item.observation_index.to_string())
        output.write_string(")\n")
      }
      match location.max_distance_from_center_m {
        Some(distance) => {
          output.write_string("  Maximum center distance: ")
          output.write_string(distance.to_string())
          output.write_string(" m\n")
        }
        None => output.write_string("  Maximum center distance: unavailable\n")
      }
      output.write_string(
        if location.wide_component {
          "  Wide component: yes\n"
        } else {
          "  Wide component: no\n"
        },
      )
      if report.options.include_coordinates {
        match location.center {
          Some(center) => {
            output.write_string("  Center (sensitive): ")
            output.write_string(center.latitude.to_string())
            output.write_string(", ")
            output.write_string(center.longitude.to_string())
            output.write_char('\n')
          }
          None => output.write_string("  Center: unavailable\n")
        }
      }
    }
  }

  output.write_string("\nMetadata exposure\n")
  if metadata.is_empty() {
    output.write_string("- none\n")
  } else {
    for finding in metadata {
      output.write_string("- ")
      output.write_string(json_string(finding.source_path))
      output.write_string(": ")
      if finding.category.to_string() ==
        @model.MetadataCategory::PointTimestamp.to_string() {
        output.write_string(
          if finding.occurrence_count == 0 {
            "timestamp absent at point "
          } else {
            "timestamp present at point "
          },
        )
        output.write_string(finding.item_ordinal.to_string())
      } else {
        output.write_string(finding.category.to_string())
        output.write_string(" (item ")
        output.write_string(finding.item_ordinal.to_string())
        output.write_string(", ")
        output.write_string(finding.occurrence_count.to_string())
        output.write_string(
          if finding.occurrence_count == 1 {
            " occurrence)"
          } else {
            " occurrences)"
          },
        )
      }
      output.write_char('\n')
    }
  }

  output.write_string("\nDiagnostics\n")
  if diagnostics.is_empty() {
    output.write_string("- none\n")
  } else {
    for diagnostic in diagnostics {
      output.write_string("- ")
      output.write_string(diagnostic.severity.to_string())
      output.write_char(' ')
      output.write_string(diagnostic.code)
      if diagnostic.path != "" {
        output.write_string(" [")
        output.write_string(json_string(diagnostic.path))
        output.write_char(']')
      }
      output.write_string(": ")
      output.write_string(diagnostic.message)
      output.write_char('\n')
    }
  }
  output.write_string(
    "\nPrivacy note: repeated endpoints are clues only; they do not identify a home or workplace and do not prove anonymity.\n",
  )
  output.to_string()
}
