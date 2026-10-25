///|
async test "library preview creates neither source path nor output paths" {
  let root = @fs.tmpdir(prefix="trackshield-preview-")
  defer @fs.rmdir(root)
  let source_path = root + "/must-not-create/source.gpx"
  assert_false(@fs.exists(source_path))
  let before = @fs.readdir(root, sort=true)
  let bytes = @utf8.encode(
    "<gpx version=\"1.1\" creator=\"test\" xmlns=\"http://www.topografix.com/GPX/1/1\"><wpt lat=\"0\" lon=\"0\"/></gpx>",
  )
  let options = @api.make_redaction_options(
    @api.make_geo_point(0.0, 0.0).unwrap(),
    1000.0,
    [],
  ).unwrap()
  let result = @api.preview_redaction(
    @api.GpxInput::new(source_path, bytes),
    options,
    @api.default_input_limits(),
  )
  assert_eq(result.points_removed, 1)
  assert_true(result.output_would_be_empty)
  assert_false(@fs.exists(source_path))
  assert_false(@fs.exists(root + "/must-not-create"))
  assert_eq(@fs.readdir(root, sort=true), before)
}

///|
async test "opaque empty segment preview and transformation create no paths" {
  let root = @fs.tmpdir(prefix="trackshield-opaque-preview-")
  defer @fs.rmdir(root)
  let source_path = root + "/must-not-create/source.gpx"
  let before = @fs.readdir(root, sort=true)
  let bytes = @utf8.encode(
    "<gpx version=\"1.1\" creator=\"test\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg><![CDATA[keep 😀]]><extensions><x xmlns=\"urn:test\"/></extensions></trkseg><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg></trk></gpx>",
  )
  let input = @api.GpxInput::new(source_path, bytes)
  let options = @api.make_redaction_options(
    @api.make_geo_point(0.0, 0.0).unwrap(),
    1000.0,
    [@api.MetadataCategory::Extensions],
  ).unwrap()
  let result = @api.preview_redaction(
    input,
    options,
    @api.default_input_limits(),
  )
  let file = @api.redact_gpx(input, options, @api.default_input_limits()).unwrap()
  assert_eq(result.metadata_fields_removed, 1)
  assert_eq(file.preview.metadata_fields_removed, 1)
  assert_eq(input.bytes, bytes)
  assert_true(
    @api.inspect_gpx(
      @api.GpxInput::new(source_path, file.bytes),
      @api.default_input_limits(),
    ).analyzed,
  )
  assert_false(@fs.exists(source_path))
  assert_false(@fs.exists(root + "/must-not-create"))
  assert_eq(@fs.readdir(root, sort=true), before)
}
