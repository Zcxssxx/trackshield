///|
fn metadata_record(
  source_path : String,
  category : @model.MetadataCategory,
  item_ordinal : Int32,
  occurrence_count : Int32,
) -> @model.MetadataFinding {
  @model.make_metadata_finding(
    source_path, category, item_ordinal, occurrence_count,
  )
}

///|
fn metadata_inspection(
  source_path : String,
  findings : Array[@model.MetadataFinding],
  point_count : Int32,
  analyzed : Bool,
) -> @model.FileInspection {
  @model.make_file_inspection(
    source_path,
    [],
    findings,
    [],
    0,
    point_count,
    analyzed,
  )
}

///|
fn metadata_test_options() -> @model.AuditOptions {
  @model.make_audit_options(500.0, 3, false).unwrap()
}

///|
test "collection audit retains every metadata category in stable order" {
  let categories : Array[@model.MetadataCategory] = [
    Creator,
    MetadataName,
    MetadataDescription,
    AuthorName,
    AuthorEmail,
    Link,
    TrackName,
    TrackDescription,
    RouteName,
    RouteDescription,
    WaypointName,
    WaypointDescription,
    PointTimestamp,
    Extensions,
  ]
  let findings : Array[@model.MetadataFinding] = []
  for index, category in categories {
    findings.push(
      metadata_record("untrusted-record-path", category, index + 1, 1),
    )
  }
  let report = @audit.audit_collection(
    [metadata_inspection("collection/a.gpx", findings, 14, true)],
    metadata_test_options(),
  )
  assert_eq(report.metadata_findings.length(), categories.length())
  for finding in report.metadata_findings {
    assert_eq(finding.source_path, "collection/a.gpx")
    let mut found_category = false
    for category in categories {
      if category.to_string() == finding.category.to_string() {
        found_category = true
      }
    }
    assert_true(found_category)
  }
  for index in 1..<report.metadata_findings.length() {
    let previous = report.metadata_findings[index - 1]
    let current = report.metadata_findings[index]
    assert_true(previous.category.to_string() <= current.category.to_string())
  }
}

///|
fn timestamp_records(
  source_path : String,
  timestamp_presence : Array[Bool],
) -> Array[@model.MetadataFinding] {
  let findings : Array[@model.MetadataFinding] = []
  for index, present in timestamp_presence {
    findings.push(
      metadata_record(
        source_path,
        PointTimestamp,
        index + 1,
        if present {
          1
        } else {
          0
        },
      ),
    )
  }
  findings
}

///|
test "timestamp coverage distinguishes zero partial and complete presence" {
  let report = @audit.audit_collection(
    [
      metadata_inspection(
        "a-zero.gpx",
        timestamp_records("a-zero.gpx", [false, false, false]),
        3,
        true,
      ),
      metadata_inspection(
        "b-partial.gpx",
        timestamp_records("b-partial.gpx", [true, false, true]),
        3,
        true,
      ),
      metadata_inspection(
        "c-complete.gpx",
        timestamp_records("c-complete.gpx", [true, true, true]),
        3,
        true,
      ),
    ],
    metadata_test_options(),
  )
  assert_eq(report.metadata_findings.length(), 9)
  let mut zero_present = 0
  let mut partial_present = 0
  let mut complete_present = 0
  let mut zero_items = 0
  for finding in report.metadata_findings {
    if finding.category.to_string() ==
      @model.MetadataCategory::PointTimestamp.to_string() {
      if finding.source_path == "a-zero.gpx" {
        zero_items += 1
        zero_present += finding.occurrence_count
      } else if finding.source_path == "b-partial.gpx" {
        partial_present += finding.occurrence_count
      } else if finding.source_path == "c-complete.gpx" {
        complete_present += finding.occurrence_count
      }
    }
  }
  assert_eq(zero_items, 3)
  assert_eq(zero_present, 0)
  assert_eq(partial_present, 2)
  assert_eq(complete_present, 3)
}

///|
fn metadata_summary(report : @model.AuditReport) -> String {
  let mut summary = ""
  for finding in report.metadata_findings {
    summary += finding.source_path +
      "/" +
      finding.category.to_string() +
      "/" +
      finding.item_ordinal.to_string() +
      "/" +
      finding.occurrence_count.to_string() +
      ";"
  }
  for diagnostic in report.diagnostics {
    summary += diagnostic.code +
      "/" +
      diagnostic.path +
      "/" +
      diagnostic.severity.to_string() +
      "/" +
      diagnostic.message +
      ";"
  }
  summary
}

///|
test "same category and ordinal remain distinct by file and input order is stable" {
  let creator_a = metadata_inspection(
    "a.gpx",
    [metadata_record("ignored-a", Creator, 1, 1)],
    0,
    true,
  )
  let creator_b = metadata_inspection(
    "b.gpx",
    [metadata_record("ignored-b", Creator, 1, 1)],
    0,
    true,
  )
  let track = metadata_inspection(
    "a.gpx",
    [metadata_record("ignored-track", TrackName, 2, 1)],
    0,
    true,
  )
  let first = @audit.audit_collection(
    [creator_a, creator_b, track],
    metadata_test_options(),
  )
  let reordered = @audit.audit_collection(
    [track, creator_b, creator_a],
    metadata_test_options(),
  )
  assert_eq(first.metadata_findings.length(), 3)
  assert_eq(first.metadata_findings[0].source_path, "a.gpx")
  assert_eq(first.metadata_findings[1].source_path, "a.gpx")
  assert_eq(first.metadata_findings[2].source_path, "b.gpx")
  assert_eq(metadata_summary(first), metadata_summary(reordered))
}

///|
test "duplicate metadata identities do not double-count a source field" {
  let report = @audit.audit_collection(
    [
      metadata_inspection(
        "same.gpx",
        [
          metadata_record("same.gpx", AuthorEmail, 1, 1),
          metadata_record("duplicate.gpx", AuthorEmail, 1, 1),
          metadata_record("same.gpx", AuthorEmail, 1, 3),
        ],
        0,
        true,
      ),
      metadata_inspection(
        "same.gpx",
        [metadata_record("again.gpx", AuthorEmail, 1, 2)],
        0,
        true,
      ),
    ],
    metadata_test_options(),
  )
  assert_eq(report.metadata_findings.length(), 1)
  assert_eq(report.metadata_findings[0].source_path, "same.gpx")
  assert_eq(report.metadata_findings[0].occurrence_count, 3)
}

///|
test "metadata from unanalyzed inputs is excluded while diagnostics remain" {
  let failed = @model.make_file_inspection(
    "broken.gpx",
    [],
    [metadata_record("private-name", MetadataName, 1, 1)],
    [
      @model.Diagnostic::new(
        @model.code_gpx_parse_failed,
        @model.Error,
        "broken.gpx",
        "GPX document could not be parsed",
      ),
    ],
    0,
    0,
    false,
  )
  let report = @audit.audit_collection([failed], metadata_test_options())
  assert_eq(report.metadata_findings.length(), 0)
  assert_eq(report.diagnostics.length(), 1)
  assert_eq(report.diagnostics[0].code, @model.code_gpx_parse_failed)
}

///|
test "invalid metadata coverage facts are omitted with a safe diagnostic" {
  let report = @audit.audit_collection(
    [
      metadata_inspection(
        "bad-coverage.gpx",
        [
          metadata_record("bad-coverage.gpx", Creator, 0, 1),
          metadata_record("bad-coverage.gpx", TrackName, 1, 0),
          metadata_record("bad-coverage.gpx", PointTimestamp, 2, 1),
        ],
        1,
        true,
      ),
    ],
    metadata_test_options(),
  )
  assert_eq(report.metadata_findings.length(), 0)
  assert_eq(report.diagnostics.length(), 3)
  for diagnostic in report.diagnostics {
    assert_eq(diagnostic.code, @model.code_invalid_metadata_finding)
    assert_false(diagnostic.message.contains("bad-coverage"))
  }
}
