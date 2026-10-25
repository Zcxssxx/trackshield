///|
test "public API re-exports validated constructors and defaults" {
  let point = match @api.make_geo_point(12.5, -44.25) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(point.latitude, 12.5)
  assert_eq(point.longitude, -44.25)
  let options = @api.default_audit_options()
  assert_eq(options.radius_m, 500.0)
  assert_eq(options.min_distinct_files, 3)
  assert_eq(options.include_coordinates, false)
  let limits = match @api.make_input_limits(4096, 100, 8, 8192, 64, 1000) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(limits.max_xml_elements, 1000)
  let input = @api.GpxInput::new("sample.gpx", Bytes::from_array([]))
  assert_eq(input.path, "sample.gpx")
  let center = match @api.make_geo_point(0.0, 0.0) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  let redaction = match
    @api.make_redaction_options(center, 250.0, [
      @api.MetadataCategory::TrackName,
    ]) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
  assert_eq(redaction.remove_metadata.length(), 1)
}
