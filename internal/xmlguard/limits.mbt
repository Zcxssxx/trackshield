///|
/// Check one input against the file-byte limit and XML preflight rules.
pub fn validate_input(
  path : String,
  bytes : Bytes,
  limits : @model.InputLimits,
) -> Array[@model.Diagnostic] {
  if bytes.length() > limits.max_file_bytes {
    return [
      @model.Diagnostic::new(
        @model.code_file_too_large,
        @model.Error,
        path,
        "file exceeds the configured byte limit",
      ),
    ]
  }
  match preflight_xml(bytes, limits.max_xml_depth, limits.max_xml_elements) {
    Ok(_) => []
    Err(diagnostic) =>
      [
        @model.Diagnostic::new(
          diagnostic.code,
          diagnostic.severity,
          path,
          diagnostic.message,
        ),
      ]
  }
}
