///|
/// Stable diagnostic levels returned by TrackShield operations.
pub(all) enum Severity {
  Info
  Warning
  Error
}

///|
/// Stable lowercase severity label for reports.
pub fn Severity::to_string(self : Severity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
/// A machine-readable issue with a safe, human-readable explanation.
pub struct Diagnostic {
  code : String
  severity : Severity
  path : String
  message : String
}

///|
/// Stable diagnostic codes used across the library and CLI.
pub let code_invalid_latitude : String = "geo.invalid_latitude"

///|
pub let code_invalid_longitude : String = "geo.invalid_longitude"

///|
pub let code_invalid_radius : String = "geo.invalid_radius"

///|
pub let code_invalid_support : String = "audit.invalid_support"

///|
pub let code_invalid_limits : String = "input.invalid_limits"

///|
pub let code_file_too_large : String = "input.file_too_large"

///|
pub let code_invalid_utf8 : String = "xml.invalid_utf8"

///|
pub let code_unsupported_encoding : String = "xml.unsupported_encoding"

///|
pub let code_doctype_forbidden : String = "xml.doctype_forbidden"

///|
pub let code_xml_too_deep : String = "xml.depth_limit"

///|
pub let code_xml_too_many_elements : String = "xml.element_limit"

///|
pub let code_invalid_xml : String = "xml.invalid_document"

///|
pub let code_unsupported_namespace : String = "gpx.unsupported_namespace"

///|
pub let code_gpx_parse_failed : String = "gpx.parse_failed"

///|
/// Construct a diagnostic. Callers should keep `message` free of source data.
pub fn Diagnostic::new(
  code : String,
  severity : Severity,
  path : String,
  message : String,
) -> Diagnostic {
  { code, severity, path, message, }
}

///|
/// Render only the stable code and safe explanation; paths are omitted by default.
pub fn Diagnostic::to_string(self : Diagnostic) -> String {
  self.code + ": " + self.message
}
