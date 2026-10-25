///|
/// A byte range inside the validated UTF-8 input.
priv struct Span {
  start : Int32
  end : Int32
}

///|
/// Parsed start-tag boundaries and the attributes relevant to namespace policy.
priv struct StartTag {
  name : Span
  next : Int32
  self_closing : Bool
  default_namespace : Span?
  version : Span?
}

///|
const GPX_10_NAMESPACE : String = "http://www.topografix.com/GPX/1/0"

///|
const GPX_11_NAMESPACE : String = "http://www.topografix.com/GPX/1/1"

///|
/// Validate UTF-8, XML structure, resource limits, DTD policy and GPX namespaces.
pub fn preflight_xml(
  bytes : Bytes,
  max_depth : Int32,
  max_elements : Int32,
  max_points~ : Int32 = 1_000_000,
) -> Result[Unit, @model.Diagnostic] {
  if max_depth <= 0 || max_elements <= 0 || max_points <= 0 {
    return Err(
      make_error(
        @model.code_invalid_limits, "XML preflight limits must be positive",
      ),
    )
  }
  if !is_valid_utf8(bytes) {
    return Err(
      make_error(@model.code_invalid_utf8, "input must be well-formed UTF-8"),
    )
  }

  let length = bytes.length()
  let content_start = if length >= 3 &&
    byte_at(bytes, 0) == 0xEF &&
    byte_at(bytes, 1) == 0xBB &&
    byte_at(bytes, 2) == 0xBF {
    3
  } else {
    0
  }
  let element_stack : Array[Span] = []
  let extension_stack : Array[Bool] = []
  let mut root_namespace : Span? = None
  let mut root_seen = false
  let mut root_closed = false
  let mut element_count = 0
  let mut point_count = 0
  let mut cursor = content_start

  while cursor < length {
    if byte_at(bytes, cursor) != 0x3C {
      if element_stack.length() == 0 && !is_xml_space(byte_at(bytes, cursor)) {
        return Err(invalid_xml())
      }
      cursor += 1
    } else if ascii_equals_at(bytes, cursor, "<!--", false) {
      match find_ascii(bytes, cursor + 4, "-->") {
        Some(end) => cursor = end + 3
        None => return Err(invalid_xml())
      }
    } else if ascii_equals_at(bytes, cursor, "<![CDATA[", false) {
      if element_stack.length() == 0 {
        return Err(invalid_xml())
      }
      match find_ascii(bytes, cursor + 9, "]]>") {
        Some(end) => cursor = end + 3
        None => return Err(invalid_xml())
      }
    } else if ascii_equals_at(bytes, cursor, "<?", false) {
      match find_ascii(bytes, cursor + 2, "?>") {
        Some(end) => {
          if is_xml_declaration(bytes, cursor) {
            if cursor != content_start ||
              root_seen ||
              !xml_declaration_uses_utf8(bytes, cursor, end) {
              return Err(
                make_error(
                  @model.code_unsupported_encoding, "only UTF-8 XML input is supported",
                ),
              )
            }
          }
          cursor = end + 2
        }
        None => return Err(invalid_xml())
      }
    } else if ascii_equals_at(bytes, cursor, "<!DOCTYPE", true) {
      return Err(
        make_error(
          @model.code_doctype_forbidden, "document type declarations are not supported",
        ),
      )
    } else if ascii_equals_at(bytes, cursor, "<!", false) {
      return Err(invalid_xml())
    } else if ascii_equals_at(bytes, cursor, "</", false) {
      match parse_end_tag(bytes, cursor) {
        Ok((name, next)) => {
          if element_stack.length() == 0 {
            return Err(invalid_xml())
          }
          let expected = element_stack[element_stack.length() - 1]
          if !same_span(bytes, name, expected) {
            return Err(invalid_xml())
          }
          let _ = element_stack.pop()
          let _ = extension_stack.pop()
          cursor = next
          if element_stack.length() == 0 {
            root_closed = true
          }
        }
        Err(diagnostic) => return Err(diagnostic)
      }
    } else {
      if root_closed {
        return Err(invalid_xml())
      }
      match parse_start_tag(bytes, cursor) {
        Err(diagnostic) => return Err(diagnostic)
        Ok(tag) => {
          let is_root = !root_seen
          let parent_in_extension = extension_stack.length() > 0 &&
            extension_stack[extension_stack.length() - 1]
          if is_root {
            match validate_root_tag(bytes, tag) {
              Err(diagnostic) => return Err(diagnostic)
              Ok(root_ns) => root_namespace = root_ns
            }
            root_seen = true
          } else {
            if contains_colon(bytes, tag.name) && !parent_in_extension {
              return Err(unsupported_namespace())
            }
            if !parent_in_extension &&
              !namespace_matches_parent(
                bytes,
                root_namespace,
                tag.default_namespace,
              ) {
              return Err(unsupported_namespace())
            }
          }

          if !parent_in_extension &&
            (
              span_equals_ascii(bytes, tag.name, "wpt") ||
              span_equals_ascii(bytes, tag.name, "rtept") ||
              span_equals_ascii(bytes, tag.name, "trkpt")
            ) {
            point_count += 1
            if point_count > max_points {
              return Err(
                make_error(
                  @model.code_point_limit_exceeded, "GPX point count exceeds the configured limit",
                ),
              )
            }
          }

          element_count += 1
          if element_count > max_elements {
            return Err(
              make_error(
                @model.code_xml_too_many_elements, "XML element count exceeds the configured limit",
              ),
            )
          }
          let depth = element_stack.length() + 1
          if depth > max_depth {
            return Err(
              make_error(
                @model.code_xml_too_deep, "XML nesting exceeds the configured limit",
              ),
            )
          }

          let is_extensions = span_equals_ascii(bytes, tag.name, "extensions")
          let in_extension = parent_in_extension || is_extensions
          cursor = tag.next
          if tag.self_closing {
            if is_root {
              root_closed = true
            }
          } else {
            element_stack.push(tag.name)
            extension_stack.push(in_extension)
          }
        }
      }
    }
  }

  if !root_seen || !root_closed || element_stack.length() != 0 {
    Err(invalid_xml())
  } else {
    Ok(())
  }
}

///|
/// Reject non-scalar, overlong, truncated, or otherwise malformed UTF-8 bytes.
fn is_valid_utf8(bytes : Bytes) -> Bool {
  let length = bytes.length()
  let mut index = 0
  while index < length {
    let first = byte_at(bytes, index)
    if first <= 0x7F {
      index += 1
    } else if first >= 0xC2 && first <= 0xDF {
      if index + 1 >= length || !is_continuation(byte_at(bytes, index + 1)) {
        return false
      }
      index += 2
    } else if first == 0xE0 {
      if index + 2 >= length ||
        byte_at(bytes, index + 1) < 0xA0 ||
        byte_at(bytes, index + 1) > 0xBF ||
        !is_continuation(byte_at(bytes, index + 2)) {
        return false
      }
      index += 3
    } else if (first >= 0xE1 && first <= 0xEC) ||
      (first >= 0xEE && first <= 0xEF) {
      if index + 2 >= length ||
        !is_continuation(byte_at(bytes, index + 1)) ||
        !is_continuation(byte_at(bytes, index + 2)) {
        return false
      }
      index += 3
    } else if first == 0xED {
      if index + 2 >= length ||
        byte_at(bytes, index + 1) < 0x80 ||
        byte_at(bytes, index + 1) > 0x9F ||
        !is_continuation(byte_at(bytes, index + 2)) {
        return false
      }
      index += 3
    } else if first == 0xF0 {
      if index + 3 >= length ||
        byte_at(bytes, index + 1) < 0x90 ||
        byte_at(bytes, index + 1) > 0xBF ||
        !is_continuation(byte_at(bytes, index + 2)) ||
        !is_continuation(byte_at(bytes, index + 3)) {
        return false
      }
      index += 4
    } else if first >= 0xF1 && first <= 0xF3 {
      if index + 3 >= length ||
        !is_continuation(byte_at(bytes, index + 1)) ||
        !is_continuation(byte_at(bytes, index + 2)) ||
        !is_continuation(byte_at(bytes, index + 3)) {
        return false
      }
      index += 4
    } else if first == 0xF4 {
      if index + 3 >= length ||
        byte_at(bytes, index + 1) < 0x80 ||
        byte_at(bytes, index + 1) > 0x8F ||
        !is_continuation(byte_at(bytes, index + 2)) ||
        !is_continuation(byte_at(bytes, index + 3)) {
        return false
      }
      index += 4
    } else {
      return false
    }
  }
  true
}

///|
fn is_continuation(byte : Int32) -> Bool {
  byte >= 0x80 && byte <= 0xBF
}

///|
fn byte_at(bytes : Bytes, index : Int32) -> Int32 {
  bytes[index].to_int()
}

///|
fn is_xml_space(byte : Int32) -> Bool {
  byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
}

///|
fn ascii_equals_at(
  bytes : Bytes,
  start : Int32,
  token : String,
  ignore_case : Bool,
) -> Bool {
  if start < 0 || start + token.length() > bytes.length() {
    return false
  }
  let mut index = 0
  for character in token {
    let actual = byte_at(bytes, start + index)
    let expected = character.to_int()
    if ignore_case {
      if ascii_lower(actual) != ascii_lower(expected) {
        return false
      }
    } else if actual != expected {
      return false
    }
    index += 1
  }
  true
}

///|
fn ascii_lower(byte : Int32) -> Int32 {
  if byte >= 0x41 && byte <= 0x5A {
    byte + 0x20
  } else {
    byte
  }
}

///|
fn find_ascii(bytes : Bytes, start : Int32, token : String) -> Int32? {
  let last_start = bytes.length() - token.length()
  let mut index = start
  while index <= last_start {
    if ascii_equals_at(bytes, index, token, false) {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
fn parse_start_tag(
  bytes : Bytes,
  open : Int32,
) -> Result[StartTag, @model.Diagnostic] {
  let length = bytes.length()
  let name_start = open + 1
  let mut cursor = name_start
  while cursor < length && !is_name_delimiter(byte_at(bytes, cursor)) {
    cursor += 1
  }
  if cursor == name_start {
    return Err(invalid_xml())
  }
  let name = { start: name_start, end: cursor, }
  let mut ns_span : Span? = None
  let mut version : Span? = None
  let mut self_closing = false
  let mut complete = false

  while cursor < length && !complete {
    while cursor < length && is_xml_space(byte_at(bytes, cursor)) {
      cursor += 1
    }
    if cursor >= length {
      return Err(invalid_xml())
    }
    if byte_at(bytes, cursor) == 0x3E {
      cursor += 1
      complete = true
    } else if byte_at(bytes, cursor) == 0x2F &&
      cursor + 1 < length &&
      byte_at(bytes, cursor + 1) == 0x3E {
      cursor += 2
      self_closing = true
      complete = true
    } else {
      let attribute_start = cursor
      while cursor < length &&
            !is_xml_space(byte_at(bytes, cursor)) &&
            byte_at(bytes, cursor) != 0x3D &&
            byte_at(bytes, cursor) != 0x3E &&
            byte_at(bytes, cursor) != 0x2F {
        cursor += 1
      }
      if cursor == attribute_start {
        return Err(invalid_xml())
      }
      let attribute_name = { start: attribute_start, end: cursor, }
      while cursor < length && is_xml_space(byte_at(bytes, cursor)) {
        cursor += 1
      }
      if cursor >= length || byte_at(bytes, cursor) != 0x3D {
        return Err(invalid_xml())
      }
      cursor += 1
      while cursor < length && is_xml_space(byte_at(bytes, cursor)) {
        cursor += 1
      }
      if cursor >= length ||
        (byte_at(bytes, cursor) != 0x22 && byte_at(bytes, cursor) != 0x27) {
        return Err(invalid_xml())
      }
      let quote = byte_at(bytes, cursor)
      cursor += 1
      let value_start = cursor
      while cursor < length && byte_at(bytes, cursor) != quote {
        if byte_at(bytes, cursor) == 0x3C {
          return Err(invalid_xml())
        }
        cursor += 1
      }
      if cursor >= length {
        return Err(invalid_xml())
      }
      let value = { start: value_start, end: cursor, }
      if span_equals_ascii(bytes, attribute_name, "xmlns") {
        ns_span = Some(value)
      } else if span_equals_ascii(bytes, attribute_name, "version") {
        version = Some(value)
      }
      cursor += 1
    }
  }

  if !complete {
    Err(invalid_xml())
  } else {
    Ok({
      name,
      next: cursor,
      self_closing,
      default_namespace: ns_span,
      version,
    })
  }
}

///|
fn parse_end_tag(
  bytes : Bytes,
  open : Int32,
) -> Result[(Span, Int32), @model.Diagnostic] {
  let length = bytes.length()
  let name_start = open + 2
  let mut cursor = name_start
  while cursor < length && !is_name_delimiter(byte_at(bytes, cursor)) {
    cursor += 1
  }
  if cursor == name_start {
    return Err(invalid_xml())
  }
  let name = { start: name_start, end: cursor, }
  while cursor < length && is_xml_space(byte_at(bytes, cursor)) {
    cursor += 1
  }
  if cursor >= length || byte_at(bytes, cursor) != 0x3E {
    Err(invalid_xml())
  } else {
    Ok((name, cursor + 1))
  }
}

///|
fn is_name_delimiter(byte : Int32) -> Bool {
  is_xml_space(byte) ||
  byte == 0x2F ||
  byte == 0x3E ||
  byte == 0x3D ||
  byte == 0x3F
}

///|
fn validate_root_tag(
  bytes : Bytes,
  tag : StartTag,
) -> Result[Span?, @model.Diagnostic] {
  if contains_colon(bytes, tag.name) {
    return Err(unsupported_namespace())
  }
  if !span_equals_ascii(bytes, tag.name, "gpx") {
    return Err(invalid_xml())
  }
  match tag.default_namespace {
    None => Ok(None)
    Some(ns_value) =>
      if ns_value.start == ns_value.end {
        Ok(None)
      } else if span_equals_ascii(bytes, ns_value, GPX_10_NAMESPACE) {
        if version_is(bytes, tag.version, "1.1") {
          Err(unsupported_namespace())
        } else {
          Ok(Some(ns_value))
        }
      } else if span_equals_ascii(bytes, ns_value, GPX_11_NAMESPACE) {
        if version_is(bytes, tag.version, "1.0") {
          Err(unsupported_namespace())
        } else {
          Ok(Some(ns_value))
        }
      } else {
        Err(unsupported_namespace())
      }
  }
}

///|
fn version_is(bytes : Bytes, version : Span?, expected : String) -> Bool {
  match version {
    None => false
    Some(value) => span_equals_ascii(bytes, value, expected)
  }
}

///|
fn namespace_matches_parent(
  bytes : Bytes,
  root_namespace : Span?,
  child_namespace : Span?,
) -> Bool {
  match child_namespace {
    None => true
    Some(child) =>
      if child.start == child.end {
        root_namespace is None
      } else {
        match root_namespace {
          None => false
          Some(root) => same_span(bytes, child, root)
        }
      }
  }
}

///|
fn contains_colon(bytes : Bytes, span : Span) -> Bool {
  let mut index = span.start
  while index < span.end {
    if byte_at(bytes, index) == 0x3A {
      return true
    }
    index += 1
  }
  false
}

///|
fn same_span(bytes : Bytes, left : Span, right : Span) -> Bool {
  if left.end - left.start != right.end - right.start {
    return false
  }
  let mut index = 0
  while index < left.end - left.start {
    if byte_at(bytes, left.start + index) != byte_at(bytes, right.start + index) {
      return false
    }
    index += 1
  }
  true
}

///|
fn span_equals_ascii(bytes : Bytes, span : Span, text : String) -> Bool {
  if span.end - span.start != text.length() {
    return false
  }
  let mut index = 0
  for character in text {
    if byte_at(bytes, span.start + index) != character.to_int() {
      return false
    }
    index += 1
  }
  true
}

///|
fn is_xml_declaration(bytes : Bytes, open : Int32) -> Bool {
  let target_start = open + 2
  ascii_equals_at(bytes, target_start, "xml", false) &&
  (
    target_start + 3 == bytes.length() ||
    is_xml_space(byte_at(bytes, target_start + 3)) ||
    byte_at(bytes, target_start + 3) == 0x3F
  )
}

///|
fn xml_declaration_uses_utf8(bytes : Bytes, open : Int32, end : Int32) -> Bool {
  let mut index = open + 5
  while index + 8 <= end {
    if ascii_equals_at(bytes, index, "encoding", false) &&
      (index == open + 5 || is_xml_space(byte_at(bytes, index - 1))) {
      let mut cursor = index + 8
      while cursor < end && is_xml_space(byte_at(bytes, cursor)) {
        cursor += 1
      }
      if cursor < end && byte_at(bytes, cursor) == 0x3D {
        cursor += 1
        while cursor < end && is_xml_space(byte_at(bytes, cursor)) {
          cursor += 1
        }
        if cursor >= end ||
          (byte_at(bytes, cursor) != 0x22 && byte_at(bytes, cursor) != 0x27) {
          return false
        }
        let quote = byte_at(bytes, cursor)
        cursor += 1
        let value_start = cursor
        while cursor < end && byte_at(bytes, cursor) != quote {
          cursor += 1
        }
        if cursor >= end {
          return false
        }
        return span_equals_ascii(
            bytes,
            { start: value_start, end: cursor, },
            "UTF-8",
          ) ||
          span_equals_ascii_case(
            bytes,
            { start: value_start, end: cursor, },
            "UTF-8",
          )
      }
    }
    index += 1
  }
  true
}

///|
fn span_equals_ascii_case(bytes : Bytes, span : Span, text : String) -> Bool {
  if span.end - span.start != text.length() {
    return false
  }
  let mut index = 0
  for character in text {
    if ascii_lower(byte_at(bytes, span.start + index)) !=
      ascii_lower(character.to_int()) {
      return false
    }
    index += 1
  }
  true
}

///|
fn unsupported_namespace() -> @model.Diagnostic {
  make_error(
    @model.code_unsupported_namespace, "GPX uses an unsupported element namespace",
  )
}

///|
fn invalid_xml() -> @model.Diagnostic {
  make_error(@model.code_invalid_xml, "XML structure is malformed")
}

///|
fn make_error(code : String, message : String) -> @model.Diagnostic {
  @model.Diagnostic::new(code, @model.Error, "", message)
}
