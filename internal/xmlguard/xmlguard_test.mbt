///|
test "file size is checked before XML content" {
  let bytes = ascii_bytes("<gpx/>")
  let exact = limits(6, 6, 16, 4)
  assert_eq(@xmlguard.validate_input("sample.gpx", bytes, exact).length(), 0)

  let below = limits(5, 5, 16, 4)
  let too_small = @xmlguard.validate_input("sample.gpx", bytes, below)
  assert_eq(too_small.length(), 1)
  assert_eq(too_small[0].code, @model.code_file_too_large)

  let over_bytes = ascii_bytes("<gpx/>!")
  let too_large = @xmlguard.validate_input("sample.gpx", over_bytes, exact)
  assert_eq(too_large.length(), 1)
  assert_eq(too_large[0].code, @model.code_file_too_large)
}

///|
test "GPX point limits are checked lexically before model parsing" {
  let source = "<gpx version=\"1.1\" creator=\"x\" xmlns=\"http://www.topografix.com/GPX/1/1\"><wpt lat=\"1\" lon=\"2\"/><trk><trkseg><trkpt lat=\"3\" lon=\"4\"/></trkseg></trk></gpx>"
  let bytes = ascii_bytes(source)
  assert_true(@xmlguard.preflight_xml(bytes, 32, 100, max_points=2) is Ok(_))
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(bytes, 32, 100, max_points=1)),
    Some(@model.code_point_limit_exceeded),
  )
}

///|
test "real DOCTYPE declarations are rejected regardless of keyword case" {
  for
    declaration in [
      "<!DOCTYPE gpx><gpx/>", "<!doctype gpx><gpx/>", "<!DoCtYpE gpx [<!ENTITY x 'value'>]><gpx>&x;</gpx>",
    ] {
    assert_eq(
      diagnostic_code(
        @xmlguard.preflight_xml(ascii_bytes(declaration), 32, 100),
      ),
      Some(@model.code_doctype_forbidden),
    )
  }
}

///|
test "external entity syntax is rejected without echoing sentinel contents" {
  let source = "<!DOCTYPE gpx [<!ENTITY secret SYSTEM \"file:///private/sentinel\">]><gpx>&secret;</gpx>"
  let result = @xmlguard.preflight_xml(ascii_bytes(source), 32, 100)
  match result {
    Ok(_) => fail("DOCTYPE should be rejected before the XML parser")
    Err(diagnostic) => {
      assert_eq(diagnostic.code, @model.code_doctype_forbidden)
      assert_eq(
        diagnostic.to_string(),
        "xml.doctype_forbidden: document type declarations are not supported",
      )
    }
  }
}

///|
test "DOCTYPE lookalikes in comments and CDATA are harmless" {
  let source = "<gpx><!-- <!DOCTYPE fake> --><trk><![CDATA[<!DOCTYPE text>]]></trk></gpx>"
  assert_true(@xmlguard.preflight_xml(ascii_bytes(source), 32, 100) is Ok(_))
}

///|
test "DOCTYPE-looking processing instruction data is not a declaration" {
  let source = "<?note <!DOCTYPE?><gpx/>"
  assert_true(@xmlguard.preflight_xml(ascii_bytes(source), 32, 100) is Ok(_))
}

///|
test "quoted attribute text cannot masquerade as a declaration" {
  let source = "<gpx note=\"&lt;!DOCTYPE not markup\"/>"
  assert_true(@xmlguard.preflight_xml(ascii_bytes(source), 32, 100) is Ok(_))
  let raw_markup = "<gpx note=\"<!DOCTYPE fake\"/>"
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(ascii_bytes(raw_markup), 32, 100)),
    Some(@model.code_invalid_xml),
  )
}

///|
test "valid multibyte UTF-8 is retained by the preflight scanner" {
  let prefix = ascii_bytes("<gpx>")
  let suffix = ascii_bytes("</gpx>")
  let greek_alpha = Bytes::from_array([(0xCE).to_byte(), (0xB1).to_byte()])
  let document = Bytes::from_array(
    [..prefix.to_array(), ..greek_alpha.to_array(), ..suffix.to_array()],
  )
  assert_true(@xmlguard.preflight_xml(document, 32, 100) is Ok(_))
}

///|
test "UTF-8 BOM is accepted and malformed byte sequences are rejected" {
  let body = ascii_bytes("<gpx/>")
  let bom = Bytes::from_array(
    [(0xEF).to_byte(), (0xBB).to_byte(), (0xBF).to_byte(), ..body.to_array()],
  )
  assert_true(@xmlguard.preflight_xml(bom, 32, 100) is Ok(_))

  let malformed = [
    Bytes::from_array([(0x80).to_byte()]),
    Bytes::from_array([(0xC0).to_byte(), (0xAF).to_byte()]),
    Bytes::from_array([(0xED).to_byte(), (0xA0).to_byte(), (0x80).to_byte()]),
    Bytes::from_array([
      (0xF4).to_byte(),
      (0x90).to_byte(),
      (0x80).to_byte(),
      (0x80).to_byte(),
    ]),
    Bytes::from_array([(0xE2).to_byte(), (0x82).to_byte()]),
  ]
  for bytes in malformed {
    assert_eq(
      diagnostic_code(@xmlguard.preflight_xml(bytes, 32, 100)),
      Some(@model.code_invalid_utf8),
    )
  }
}

///|
test "only UTF-8 XML declarations are accepted" {
  let accepted = ascii_bytes("<?xml version=\"1.0\" encoding=\"UTF-8\"?><gpx/>")
  assert_true(@xmlguard.preflight_xml(accepted, 32, 100) is Ok(_))
  let rejected = ascii_bytes(
    "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><gpx/>",
  )
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(rejected, 32, 100)),
    Some(@model.code_unsupported_encoding),
  )
}

///|
test "XML nesting and element counts are bounded before model parsing" {
  let exact_depth = ascii_bytes("<gpx><a><b/></a></gpx>")
  assert_true(@xmlguard.preflight_xml(exact_depth, 3, 10) is Ok(_))
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(exact_depth, 2, 10)),
    Some(@model.code_xml_too_deep),
  )

  let three_elements = ascii_bytes("<gpx><a/><b/></gpx>")
  assert_true(@xmlguard.preflight_xml(three_elements, 8, 3) is Ok(_))
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(three_elements, 8, 2)),
    Some(@model.code_xml_too_many_elements),
  )
}

///|
test "non-positive preflight bounds return a stable configuration error" {
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(ascii_bytes("<gpx/>"), 0, 10)),
    Some(@model.code_invalid_limits),
  )
  assert_eq(
    diagnostic_code(@xmlguard.preflight_xml(ascii_bytes("<gpx/>"), 10, 0)),
    Some(@model.code_invalid_limits),
  )
}

///|
test "mismatched tags, unfinished comments, and missing roots fail" {
  for
    source in [
      "<gpx><trk></gpx>", "<gpx><!-- unfinished</gpx>", "text without a root",
    ] {
    assert_eq(
      diagnostic_code(@xmlguard.preflight_xml(ascii_bytes(source), 32, 100)),
      Some(@model.code_invalid_xml),
    )
  }
}

///|
test "supported GPX namespace URIs must match their version" {
  for
    source in [
      "<gpx version=\"1.1\" xmlns=\"urn:wrong\"/>", "<gpx version=\"1.1\" xmlns=\"http://www.topografix.com/GPX/1/0\"/>",
      "<gpx version=\"1.0\" xmlns=\"http://www.topografix.com/GPX/1/1\"/>", "<g:gpx xmlns:g=\"http://www.topografix.com/GPX/1/1\" version=\"1.1\"/>",
      "<gpx version=\"1.1\"><g:trk/></gpx>",
    ] {
    assert_eq(
      diagnostic_code(@xmlguard.preflight_xml(ascii_bytes(source), 32, 100)),
      Some(@model.code_unsupported_namespace),
    )
  }

  for
    source in [
      "<gpx version=\"1.1\" xmlns=\"http://www.topografix.com/GPX/1/1\"/>", "<gpx version=\"1.0\" xmlns=\"http://www.topografix.com/GPX/1/0\"/>",
      "<gpx version=\"1.1\"/>",
    ] {
    assert_true(@xmlguard.preflight_xml(ascii_bytes(source), 32, 100) is Ok(_))
  }

  let prefixed_extension = "<gpx version=\"1.1\" xmlns=\"http://www.topografix.com/GPX/1/1\"><extensions><x:detail xmlns:x=\"urn:vendor\"/></extensions></gpx>"
  assert_true(
    @xmlguard.preflight_xml(ascii_bytes(prefixed_extension), 32, 100) is Ok(_),
  )
}

///|
fn ascii_bytes(source : String) -> Bytes {
  let bytes : Array[Byte] = []
  for character in source {
    bytes.push(character.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn diagnostic_code(result : Result[Unit, @model.Diagnostic]) -> String? {
  match result {
    Ok(_) => None
    Err(diagnostic) => Some(diagnostic.code)
  }
}

///|
fn limits(
  max_file_bytes : Int32,
  max_total_bytes : Int32,
  max_xml_depth : Int32,
  max_xml_elements : Int32,
) -> @model.InputLimits raise {
  match
    @model.make_input_limits(
      max_file_bytes, 1, 1, max_total_bytes, max_xml_depth, max_xml_elements,
    ) {
    Ok(value) => value
    Err(diagnostic) => fail(diagnostic.to_string())
  }
}
