///|
/// Caller-supplied file content and its local display path.
pub struct GpxInput {
  path : String
  bytes : Bytes
}

///|
/// Associate caller-provided bytes with a local source label.
pub fn GpxInput::new(path : String, bytes : Bytes) -> GpxInput {
  { path, bytes, }
}

///|
/// Resource limits applied before and after XML parsing.
pub struct InputLimits {
  max_file_bytes : Int32
  max_points_per_file : Int32
  max_files : Int32
  max_total_bytes : Int32
  max_xml_depth : Int32
  max_xml_elements : Int32
}

///|
const MAX_FILE_BYTES : Int32 = 64 * 1024 * 1024

///|
const MAX_POINTS_PER_FILE : Int32 = 1_000_000

///|
const MAX_FILES : Int32 = 5_000

///|
const MAX_TOTAL_BYTES : Int32 = 1_073_741_824

///|
const MAX_XML_DEPTH : Int32 = 256

///|
const MAX_XML_ELEMENTS : Int32 = 2_000_000

///|
/// Build validated resource limits within hard implementation ceilings.
pub fn make_input_limits(
  max_file_bytes : Int32,
  max_points_per_file : Int32,
  max_files : Int32,
  max_total_bytes : Int32,
  max_xml_depth : Int32,
  max_xml_elements : Int32,
) -> Result[InputLimits, Diagnostic] {
  if max_file_bytes <= 0 ||
    max_file_bytes > MAX_FILE_BYTES ||
    max_points_per_file <= 0 ||
    max_points_per_file > MAX_POINTS_PER_FILE ||
    max_files <= 0 ||
    max_files > MAX_FILES ||
    max_total_bytes <= 0 ||
    max_total_bytes > MAX_TOTAL_BYTES ||
    max_total_bytes < max_file_bytes ||
    max_xml_depth <= 0 ||
    max_xml_depth > MAX_XML_DEPTH ||
    max_xml_elements <= 0 ||
    max_xml_elements > MAX_XML_ELEMENTS ||
    max_points_per_file > max_xml_elements {
    Err(
      Diagnostic::new(
        code_invalid_limits,
        Error,
        "",
        "resource limits are outside supported bounds",
      ),
    )
  } else {
    Ok({
      max_file_bytes,
      max_points_per_file,
      max_files,
      max_total_bytes,
      max_xml_depth,
      max_xml_elements,
    })
  }
}

///|
/// Return conservative defaults suitable for ordinary personal GPX collections.
pub fn default_input_limits() -> InputLimits {
  {
    max_file_bytes: 32 * 1024 * 1024,
    max_points_per_file: 250_000,
    max_files: 500,
    max_total_bytes: 256 * 1024 * 1024,
    max_xml_depth: 128,
    max_xml_elements: 500_000,
  }
}
