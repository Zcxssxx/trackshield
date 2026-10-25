///|
/// Validated latitude and longitude in decimal degrees.
pub struct GeoPoint {
  latitude : Double
  longitude : Double
}

///|
/// Validate latitude in [-90, 90] and longitude in [-180, 180].
pub fn make_geo_point(
  latitude : Double,
  longitude : Double,
) -> Result[GeoPoint, Diagnostic] {
  if latitude >= -90.0 && latitude <= 90.0 {
    if longitude >= -180.0 && longitude <= 180.0 {
      Ok({ latitude, longitude, })
    } else {
      Err(
        Diagnostic::new(
          code_invalid_longitude,
          Error,
          "",
          "longitude must be between -180 and 180 degrees",
        ),
      )
    }
  } else {
    Err(
      Diagnostic::new(
        code_invalid_latitude,
        Error,
        "",
        "latitude must be between -90 and 90 degrees",
      ),
    )
  }
}

///|
/// Start or end of a recorded track.
pub(all) enum EndpointKind {
  Start
  End
}

///|
/// Stable endpoint label for diagnostics and reports.
pub fn EndpointKind::to_string(self : EndpointKind) -> String {
  match self {
    Start => "start"
    End => "end"
  }
}

///|
/// Metadata field groups that may be present in a GPX export.
pub(all) enum MetadataCategory {
  Creator
  MetadataName
  MetadataDescription
  AuthorName
  AuthorEmail
  Link
  TrackName
  TrackDescription
  RouteName
  RouteDescription
  WaypointName
  WaypointDescription
  PointTimestamp
  Extensions
}

///|
/// Stable category label without exposing the stored metadata value.
pub fn MetadataCategory::to_string(self : MetadataCategory) -> String {
  match self {
    Creator => "creator"
    MetadataName => "metadata_name"
    MetadataDescription => "metadata_description"
    AuthorName => "author_name"
    AuthorEmail => "author_email"
    Link => "link"
    TrackName => "track_name"
    TrackDescription => "track_description"
    RouteName => "route_name"
    RouteDescription => "route_description"
    WaypointName => "waypoint_name"
    WaypointDescription => "waypoint_description"
    PointTimestamp => "point_timestamp"
    Extensions => "extensions"
  }
}

///|
/// One sensitive endpoint coordinate extracted from a source file.
/// Track ordinals start at 1; observation indexes start at 0 within the file.
pub struct EndpointObservation {
  source_path : String
  track_ordinal : Int32
  kind : EndpointKind
  observation_index : Int32
  point : GeoPoint
}

///|
/// Build an endpoint observation for another package in the TrackShield module.
pub fn make_endpoint_observation(
  source_path : String,
  track_ordinal : Int32,
  kind : EndpointKind,
  observation_index : Int32,
  point : GeoPoint,
) -> EndpointObservation {
  { source_path, track_ordinal, kind, observation_index, point, }
}

///|
/// A metadata category occurrence in one source file, without the source value.
/// Item ordinals start at 1; occurrence_count counts represented occurrences.
pub struct MetadataFinding {
  source_path : String
  category : MetadataCategory
  item_ordinal : Int32
  occurrence_count : Int32
}

///|
/// Build a metadata finding without retaining the metadata value itself.
pub fn make_metadata_finding(
  source_path : String,
  category : MetadataCategory,
  item_ordinal : Int32,
  occurrence_count : Int32,
) -> MetadataFinding {
  { source_path, category, item_ordinal, occurrence_count, }
}

///|
/// Parsed per-file facts. Point counts include waypoints, route points, and track
/// points. Endpoint coordinates remain in this detailed local model.
pub struct FileInspection {
  source_path : String
  endpoints : Array[EndpointObservation]
  metadata_findings : Array[MetadataFinding]
  diagnostics : Array[Diagnostic]
  track_count : Int32
  point_count : Int32
  analyzed : Bool
}

///|
/// Build an immutable snapshot of one file's inspection results.
pub fn make_file_inspection(
  source_path : String,
  endpoints : Array[EndpointObservation],
  metadata_findings : Array[MetadataFinding],
  diagnostics : Array[Diagnostic],
  track_count : Int32,
  point_count : Int32,
  analyzed : Bool,
) -> FileInspection {
  {
    source_path,
    endpoints: endpoints.copy(),
    metadata_findings: metadata_findings.copy(),
    diagnostics: diagnostics.copy(),
    track_count,
    point_count,
    analyzed,
  }
}

///|
/// Controls repeated-endpoint clustering and coordinate disclosure.
pub struct AuditOptions {
  radius_m : Double
  min_distinct_files : Int32
  include_coordinates : Bool
}

///|
const MAX_AUDIT_RADIUS_METERS : Double = 20_037_508.0

///|
const MAX_DISTINCT_FILE_THRESHOLD : Int32 = 5_000

///|
/// Validate the repeated-location search radius and support threshold.
pub fn make_audit_options(
  radius_m : Double,
  min_distinct_files : Int32,
  include_coordinates : Bool,
) -> Result[AuditOptions, Diagnostic] {
  if radius_m > 0.0 && radius_m <= MAX_AUDIT_RADIUS_METERS {
    if min_distinct_files >= 2 &&
      min_distinct_files <= MAX_DISTINCT_FILE_THRESHOLD {
      Ok({ radius_m, min_distinct_files, include_coordinates, })
    } else {
      Err(
        Diagnostic::new(
          code_invalid_support,
          Error,
          "",
          "minimum distinct-file support must be between 2 and 5000",
        ),
      )
    }
  } else {
    Err(
      Diagnostic::new(
        code_invalid_radius,
        Error,
        "",
        "radius must be positive and no larger than half the equatorial circumference",
      ),
    )
  }
}

///|
/// Use a 500 m radius, three-file threshold, and hide coordinates by default.
pub fn default_audit_options() -> AuditOptions {
  { radius_m: 500.0, min_distinct_files: 3, include_coordinates: false, }
}

///|
/// Evidence retains source identity without copying endpoint coordinates.
pub struct EndpointEvidence {
  source_path : String
  track_ordinal : Int32
  kind : EndpointKind
  observation_index : Int32
}

///|
/// Build a coordinate-free reference to one endpoint observation.
pub fn make_endpoint_evidence(
  source_path : String,
  track_ordinal : Int32,
  kind : EndpointKind,
  observation_index : Int32,
) -> EndpointEvidence {
  { source_path, track_ordinal, kind, observation_index, }
}

///|
/// A supported endpoint cluster. `center` is present only when requested.
pub struct RepeatedLocation {
  id : String
  distinct_file_count : Int32
  distinct_track_count : Int32
  evidence : Array[EndpointEvidence]
  center : GeoPoint?
  max_distance_from_center_m : Double?
  wide_component : Bool
}

///|
/// Build a repeated-endpoint component with copied evidence references.
pub fn make_repeated_location(
  id : String,
  distinct_file_count : Int32,
  distinct_track_count : Int32,
  evidence : Array[EndpointEvidence],
  center : GeoPoint?,
  max_distance_from_center_m : Double?,
  wide_component : Bool,
) -> RepeatedLocation {
  {
    id,
    distinct_file_count,
    distinct_track_count,
    evidence: evidence.copy(),
    center,
    max_distance_from_center_m,
    wide_component,
  }
}

///|
/// Collection-level audit result with privacy-safe evidence summaries.
pub struct AuditReport {
  options : AuditOptions
  repeated_locations : Array[RepeatedLocation]
  metadata_findings : Array[MetadataFinding]
  diagnostics : Array[Diagnostic]
}

///|
/// Build a collection audit snapshot with copied result arrays.
pub fn make_audit_report(
  options : AuditOptions,
  repeated_locations : Array[RepeatedLocation],
  metadata_findings : Array[MetadataFinding],
  diagnostics : Array[Diagnostic],
) -> AuditReport {
  {
    options,
    repeated_locations: repeated_locations.copy(),
    metadata_findings: metadata_findings.copy(),
    diagnostics: diagnostics.copy(),
  }
}
