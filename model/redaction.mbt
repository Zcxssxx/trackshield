///|
/// Explicitly supplied geographic circle and selected metadata categories.
pub struct RedactionOptions {
  center : GeoPoint
  radius_m : Double
  remove_metadata : Array[MetadataCategory]
}

///|
/// Counts the changes that a specific redaction would make.
pub struct RedactionPreview {
  source_path : String
  points_removed : Int32
  segments_created : Int32
  routes_removed : Int32
  waypoints_removed : Int32
  metadata_fields_removed : Int32
  output_would_be_empty : Bool
  diagnostics : Array[Diagnostic]
}

///|
/// Redacted bytes paired with the preview for the same input and options.
pub struct RedactedFile {
  bytes : Bytes
  preview : RedactionPreview
}

///|
/// Validate the user-specified clipping radius and retain metadata choices.
pub fn make_redaction_options(
  center : GeoPoint,
  radius_m : Double,
  remove_metadata : Array[MetadataCategory],
) -> Result[RedactionOptions, Diagnostic] {
  if radius_m > 0.0 && radius_m <= 20_037_508.0 {
    Ok({ center, radius_m, remove_metadata: remove_metadata.copy(), })
  } else {
    Err(
      Diagnostic::new(
        code_invalid_radius,
        Error,
        "",
        "redaction radius must be positive and no larger than half the equatorial circumference",
      ),
    )
  }
}
