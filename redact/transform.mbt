///|
/// Pure transformation of an explicit circle, preserving untouched source XML.
pub fn redact_gpx(
  input : @model.GpxInput,
  options : @model.RedactionOptions,
  limits : @model.InputLimits,
) -> Result[@model.RedactedFile, @model.Diagnostic] {
  let original = match @gpx.parse_input(input, limits) {
    Ok(document) => document
    Err(diagnostics) => return Err(diagnostics[0])
  }
  let preview = preview_redaction(input, options, limits)
  if preview.output_would_be_empty {
    return Err(
      @model.Diagnostic::new(
        "redact.empty_result",
        @model.Warning,
        input.path,
        "redaction leaves no track, route, or waypoint content",
      ),
    )
  }
  let source = @utf8.decode(input.bytes) catch {
    _ => return Err(lossless_error(input.path))
  }
  let root = match source_tree(source) {
    Ok(root) => root
    Err(_) => return Err(lossless_error(input.path))
  }
  let rendered = match rewrite_element(source, root, "", options) {
    Ok(value) => value
    Err(_) => return Err(lossless_error(input.path))
  }
  let bytes = @utf8.encode(
    source[:root.start].to_owned() +
    rendered.text +
    source[root.end:].to_owned(),
  )
  // Every candidate passes the same resource, namespace, version and range guards.
  let candidate = match
    @gpx.parse_input(@model.GpxInput::new(input.path, bytes), limits) {
    Ok(document) => document
    Err(_) => return Err(lossless_error(input.path))
  }
  if candidate.version != original.version ||
    document_point_count(candidate) !=
    document_point_count(original) - preview.points_removed ||
    candidate.waypoints.length() !=
    original.waypoints.length() - preview.waypoints_removed ||
    candidate.routes.length() !=
    original.routes.length() - preview.routes_removed ||
    document_point_count(candidate) != rendered.points ||
    candidate.tracks.fold(init=0, fn(total, track) {
      total + track.segments.length()
    }) !=
    rendered.segments {
    return Err(lossless_error(input.path))
  }
  let recheck = preview_redaction(
    @model.GpxInput::new(input.path, bytes),
    options,
    limits,
  )
  if recheck.points_removed != 0 ||
    recheck.output_would_be_empty ||
    recheck.metadata_fields_removed !=
    (if selected(options, @model.Creator) { 1 } else { 0 }) {
    return Err(lossless_error(input.path))
  }
  Ok(@model.make_redacted_file(bytes, preview))
}

///|
fn lossless_error(path : String) -> @model.Diagnostic {
  @model.Diagnostic::new(
    "gpx.lossless_redaction_unsupported",
    @model.Error,
    path,
    "the requested transformation cannot preserve unselected GPX content safely",
  )
}

///|
fn document_point_count(document : @moongpx.Gpx) -> Int32 {
  let mut count = document.waypoints.length()
  for route in document.routes {
    count += route.points.length()
  }
  for track in document.tracks {
    for segment in track.segments {
      count += segment.points.length()
    }
  }
  count
}
