///|
/// Authored fixtures keep this gate independent from upstream test data.
fn fixture_gpx_11() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<gpx version="1.1" creator="TrackShield fixture" xmlns="http://www.topografix.com/GPX/1/1">
    #|  <metadata><name>training fixture</name></metadata>
    #|  <trk><name>sample</name><trkseg>
    #|    <trkpt lat="37.0000" lon="-122.0000"><time>2026-01-01T08:00:00Z</time></trkpt>
    #|    <trkpt lat="37.0010" lon="-122.0010"><extensions><sample xmlns="urn:trackshield:fixture"><marker>opaque</marker></sample></extensions></trkpt>
    #|  </trkseg></trk>
    #|</gpx>
  )
}

///|
fn fixture_gpx_10() -> String {
  (
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<gpx version="1.0" creator="TrackShield fixture" xmlns="http://www.topografix.com/GPX/1/0">
    #|  <name>legacy fixture</name>
    #|  <trk><name>legacy track</name><trkseg>
    #|    <trkpt lat="37.0" lon="-122.0" />
    #|  </trkseg></trk>
    #|</gpx>
  )
}

///|
test "GPX 1.1 default namespace parses and serializes semantically" {
  let parsed = match @moongpx.parse_gpx(fixture_gpx_11()) {
    Ok(gpx) => gpx
    Err(diagnostics) => fail(@moongpx.format_diagnostics(diagnostics))
  }
  assert_eq(parsed.tracks.length(), 1)
  assert_eq(parsed.tracks[0].segments[0].points.length(), 2)
  let encoded = @moongpx.to_gpx(parsed)
  let round_trip = match @moongpx.parse_gpx(encoded) {
    Ok(gpx) => gpx
    Err(diagnostics) => fail(@moongpx.format_diagnostics(diagnostics))
  }
  assert_eq(round_trip, parsed)
}

///|
test "GPX 1.0 parser maps a legacy document to the shared model" {
  let parsed = match @moongpx.parse_gpx_any(fixture_gpx_10()) {
    Ok(gpx) => gpx
    Err(diagnostics) => fail(@moongpx.format_diagnostics(diagnostics))
  }
  assert_eq(parsed.version, "1.1")
  assert_eq(parsed.tracks.length(), 1)
  assert_eq(parsed.tracks[0].segments[0].points.length(), 1)
}

///|
test "prefixed GPX element names are rejected by the selected dependency" {
  let source = "<g:gpx xmlns:g=\"http://www.topografix.com/GPX/1/1\" version=\"1.1\" creator=\"fixture\"/>"
  match @moongpx.parse_gpx(source) {
    Ok(_) =>
      fail(
        "the dependency currently documents prefixed elements as unsupported",
      )
    Err(_) => ()
  }
}

///|
test "malformed XML fails without a model" {
  match
    @moongpx.parse_gpx("<gpx version=\"1.1\" creator=\"fixture\"><trk></gpx>") {
    Ok(_) => fail("unbalanced XML must be rejected")
    Err(_) => ()
  }
}

///|
test "ASCII GPX survives the validated byte-to-string bridge" {
  let source = "<gpx version=\"1.1\" creator=\"x\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg><trkpt lat=\"1\" lon=\"2\"/><trkpt lat=\"3\" lon=\"4\"/></trkseg></trk></gpx>"
  let bytes : Array[Byte] = []
  for ch in source {
    bytes.push(ch.to_int().to_byte())
  }
  let decoded = try @utf8.decode(Bytes::from_array(bytes)) catch {
    Malformed(_) => ""
  } noraise {
    value => value
  }
  assert_eq(decoded, source)
  match @moongpx.parse_gpx_any(decoded) {
    Ok(gpx) => assert_eq(gpx.tracks.length(), 1)
    Err(diagnostics) => fail(@moongpx.format_diagnostics(diagnostics))
  }
}
