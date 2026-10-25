///|
/// Public TrackShield API surface and validated domain types.
pub using @model {
  type Diagnostic,
  type Severity,
  type GpxInput,
  type InputLimits,
  type GeoPoint,
  type EndpointKind,
  type MetadataCategory,
  type EndpointObservation,
  type MetadataFinding,
  type FileInspection,
  type AuditOptions,
  type EndpointEvidence,
  type RepeatedLocation,
  type AuditReport,
  type RedactionOptions,
  type RedactionPreview,
  type RedactedFile,
  make_geo_point,
  make_input_limits,
  make_audit_options,
  make_redaction_options,
  default_input_limits,
  default_audit_options,
  code_invalid_latitude,
  code_invalid_longitude,
  code_invalid_radius,
  code_invalid_support,
  code_wide_endpoint_component,
  code_invalid_limits,
  code_file_too_large,
  code_invalid_utf8,
  code_unsupported_encoding,
  code_point_limit_exceeded,
  code_undefined_center,
  code_doctype_forbidden,
  code_xml_too_deep,
  code_xml_too_many_elements,
  code_invalid_xml,
  code_unsupported_namespace,
  code_gpx_parse_failed,
}

///|
/// Inspect one in-memory GPX document after bounded XML preflight.
pub fn inspect_gpx(input : GpxInput, limits : InputLimits) -> FileInspection {
  @gpx.inspect_gpx(input, limits)
}

///|
/// Audit a collection of per-file inspections for repeated endpoint clues.
pub fn audit_collection(
  inspections : Array[FileInspection],
  options : AuditOptions,
) -> AuditReport {
  @audit.audit_collection(inspections, options)
}

///|
/// Distance in metres along the mean-Earth-radius sphere.
pub using @geo {distance_m, max_distance_from_center, spherical_mean}
