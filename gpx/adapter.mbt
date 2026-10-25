///|
fn decoded_gpx_source(bytes : Bytes) -> Result[String, Unit] {
  let mut offset = 0
  if bytes.length() >= 3 &&
    bytes[0] == (0xEF).to_byte() &&
    bytes[1] == (0xBB).to_byte() &&
    bytes[2] == (0xBF).to_byte() {
    offset = 3
  }
  try @utf8.decode(bytes[offset:]) catch {
    Malformed(_) => Err(())
  } noraise {
    source => Ok(source)
  }
}

///|
/// Parse one GPX document without filesystem or network access.
///
/// XML bounds and encoding are validated before the semantic parser allocates
/// a GPX model. Parser messages are replaced with a static diagnostic so raw
/// metadata, coordinates, or malformed source text cannot leak into reports.
pub fn parse_input(
  input : @model.GpxInput,
  limits : @model.InputLimits,
) -> Result[@moongpx.Gpx, Array[@model.Diagnostic]] {
  let preflight = @xmlguard.validate_input(input.path, input.bytes, limits)
  if preflight.length() > 0 {
    return Err(preflight)
  }

  match decoded_gpx_source(input.bytes) {
    Err(_) =>
      Err([
        @model.Diagnostic::new(
          @model.code_invalid_utf8,
          @model.Error,
          input.path,
          "input is not valid UTF-8",
        ),
      ])
    Ok(source) =>
      match @moongpx.parse_gpx_any(source) {
        Err(_) =>
          Err([
            @model.Diagnostic::new(
              @model.code_gpx_parse_failed,
              @model.Error,
              input.path,
              "GPX document could not be parsed or failed format validation",
            ),
          ])
        Ok(document) => {
          let point_count = count_document_points(document)
          if point_count > limits.max_points_per_file {
            return Err([
              @model.Diagnostic::new(
                @model.code_point_limit_exceeded,
                @model.Error,
                input.path,
                "file contains more points than the configured limit",
              ),
            ])
          }
          Ok(document)
        }
      }
  }
}

///|
/// Inspect one GPX document through the shared bounded, privacy-safe parser.
pub fn inspect_gpx(
  input : @model.GpxInput,
  limits : @model.InputLimits,
) -> @model.FileInspection {
  match parse_input(input, limits) {
    Err(diagnostics) =>
      @model.make_file_inspection(input.path, [], [], diagnostics, 0, 0, false)
    Ok(document) =>
      @model.make_file_inspection(
        input.path,
        extract_track_endpoints(input.path, document),
        extract_metadata(input.path, document),
        [],
        document.tracks.length(),
        count_document_points(document),
        true,
      )
  }
}
