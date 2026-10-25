///|
fn transformed(
  body : String,
  categories : Array[@model.MetadataCategory],
) -> @model.RedactedFile {
  @redact.redact_gpx(
    input(body),
    options(categories),
    @model.default_input_limits(),
  ).unwrap()
}

///|
fn parsed(file : @model.RedactedFile) -> @moongpx.Gpx {
  @gpx.parse_input(
    @model.GpxInput::new("candidate.gpx", file.bytes),
    @model.default_input_limits(),
  ).unwrap()
}

///|
test "transform splits leading middle trailing and consecutive removed runs" {
  for
    (points, lengths) in [
      ([0, 1, 2], [2]),
      ([1, 0, 2], [1, 1]),
      ([1, 2, 0], [2]),
      ([0, 1, 0, 0, 2, 0, 3, 0], [1, 1, 1]),
    ] {
    let body = points
      .map(fn(p) { "<trkpt lat=\"\{p}\" lon=\"\{p}\"/>" })
      .join("")
    let result = transformed("<trk><trkseg>" + body + "</trkseg></trk>", [])
    let segments = parsed(result).tracks[0].segments
    assert_eq(segments.map(fn(s) { s.points.length() }), lengths)
    for segment in segments {
      for point in segment.points {
        assert_true(point.lat.to_double() > 0.0)
      }
    }
    assert_eq(
      result.preview.points_removed,
      points.filter(fn(p) { p == 0 }).length(),
    )
    assert_eq(result.preview.segments_created, lengths.length() - 1)
  }
}

///|
test "transform preserves original segment boundaries and omits emptied structures" {
  let result = transformed(
    "<wpt lat=\"0\" lon=\"0\"/><wpt lat=\"5\" lon=\"5\"/><rte><rtept lat=\"0\" lon=\"0\"/></rte><rte><rtept lat=\"0\" lon=\"0\"/><rtept lat=\"6\" lon=\"6\"/></rte><trk><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg></trk><trk><trkseg/><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg><trkseg><trkpt lat=\"2\" lon=\"2\"/></trkseg></trk>",
    [],
  )
  let doc = parsed(result)
  assert_eq(doc.waypoints.length(), 1)
  assert_eq(doc.routes.length(), 1)
  assert_eq(doc.routes[0].points.length(), 1)
  assert_eq(doc.tracks.length(), 1)
  assert_eq(doc.tracks[0].segments.length(), 2)
  assert_eq(result.preview.points_removed, 5)
  assert_eq(result.preview.routes_removed, 1)
  assert_eq(result.preview.waypoints_removed, 1)
  assert_true(
    result.preview.diagnostics.any(fn(d) { d.code == "redact.empty_track" }),
  )
  assert_true(
    result.preview.diagnostics.any(fn(d) { d.code == "redact.empty_route" }),
  )
}

///|
test "transform refuses all points removed and originally empty content" {
  for
    body in [
      "<metadata><name>keep</name></metadata>", "<trk><trkseg/></trk>", "<trk><trkseg><trkpt lat=\"0\" lon=\"0\"/></trkseg></trk>",
      "<wpt lat=\"0\" lon=\"0\"/><rte><rtept lat=\"0\" lon=\"0\"/></rte>",
    ] {
    match
      @redact.redact_gpx(
        input(body),
        options([]),
        @model.default_input_limits(),
      ) {
      Err(d) => assert_eq(d.code, "redact.empty_result")
      Ok(_) => fail("empty candidate must not be returned")
    }
  }
}

///|
test "transform inclusive boundary preserves just outside" {
  let center = @model.make_geo_point(0.0, 0.0).unwrap()
  let edge = @model.make_geo_point(0.0, 1.0).unwrap()
  let opts = @model.make_redaction_options(
    center,
    @geo.distance_m(center, edge),
    [],
  ).unwrap()
  let result = @redact.redact_gpx(
    input("<wpt lat=\"0\" lon=\"1\"/><wpt lat=\"0\" lon=\"1.000001\"/>"),
    opts,
    @model.default_input_limits(),
  ).unwrap()
  assert_eq(parsed(result).waypoints.length(), 1)
  assert_eq(result.preview.points_removed, 1)
}

///|
test "transform selected categories remove only requested metadata" {
  let body = "<metadata><name>mn</name><desc>md</desc><author><name>an</name><email id=\"a\" domain=\"b\"/><link href=\"https://example.invalid/a\"/></author><copyright author=\"keep\"/><link href=\"https://example.invalid/m\"/><time>2026-01-01T00:00:00Z</time><keywords>keep</keywords><extensions><x xmlns=\"urn:test\"/></extensions></metadata><wpt lat=\"1\" lon=\"1\"><ele>23</ele><time>2026-01-01T00:00:00Z</time><name>wn</name><cmt>keep</cmt><desc>wd</desc><src>keep</src><link href=\"https://example.invalid/p\"/><sym>keep</sym><extensions><x xmlns=\"urn:test\"/></extensions></wpt><rte><name>rn</name><cmt>keep</cmt><desc>rd</desc><rtept lat=\"2\" lon=\"2\"/></rte><trk><name>tn</name><cmt>keep</cmt><desc>td</desc><trkseg><trkpt lat=\"3\" lon=\"3\"/></trkseg></trk><extensions><x xmlns=\"urn:test\"/></extensions>"
  let original = @gpx.parse_input(input(body), @model.default_input_limits()).unwrap()
  assert_eq(parsed(transformed(body, [])), original)
  for
    category in [
      @model.Creator,
      @model.MetadataName,
      @model.MetadataDescription,
      @model.AuthorName,
      @model.AuthorEmail,
      @model.Link,
      @model.TrackName,
      @model.TrackDescription,
      @model.RouteName,
      @model.RouteDescription,
      @model.WaypointName,
      @model.WaypointDescription,
      @model.PointTimestamp,
      @model.Extensions,
    ] {
    let file = transformed(body, [category, category])
    assert_true(file.preview.metadata_fields_removed > 0)
    let doc = parsed(file)
    let meta = doc.metadata.unwrap()
    assert_eq(
      meta.name,
      if category.to_string() == "metadata_name" {
        None
      } else {
        original.metadata.unwrap().name
      },
    )
    assert_eq(
      meta.desc,
      if category.to_string() == "metadata_description" {
        None
      } else {
        original.metadata.unwrap().desc
      },
    )
    assert_eq(
      meta.author.unwrap().name,
      if category.to_string() == "author_name" {
        None
      } else {
        Some("an")
      },
    )
    assert_eq(
      meta.author.unwrap().email is None,
      category.to_string() == "author_email",
    )
    assert_eq(
      doc.creator,
      if category.to_string() == "creator" {
        "TrackShield"
      } else {
        "secret creator"
      },
    )
    assert_eq(doc.tracks[0].name is None, category.to_string() == "track_name")
    assert_eq(
      doc.tracks[0].desc is None,
      category.to_string() == "track_description",
    )
    assert_eq(doc.routes[0].name is None, category.to_string() == "route_name")
    assert_eq(
      doc.routes[0].desc is None,
      category.to_string() == "route_description",
    )
    assert_eq(
      doc.waypoints[0].name is None,
      category.to_string() == "waypoint_name",
    )
    assert_eq(
      doc.waypoints[0].desc is None,
      category.to_string() == "waypoint_description",
    )
    assert_eq(
      doc.waypoints[0].time is None,
      category.to_string() == "point_timestamp",
    )
    assert_eq(doc.waypoints[0].links.is_empty(), category.to_string() == "link")
    assert_eq(meta.links.is_empty(), category.to_string() == "link")
    assert_eq(meta.author.unwrap().link is None, category.to_string() == "link")
    assert_eq(meta.extensions is None, category.to_string() == "extensions")
    assert_eq(doc.extensions is None, category.to_string() == "extensions")
    assert_eq(meta.time, original.metadata.unwrap().time)
    assert_eq(meta.keywords, original.metadata.unwrap().keywords)
    assert_eq(meta.copyright, original.metadata.unwrap().copyright)
    assert_eq(doc.waypoints[0].ele, Some(23.0))
    assert_eq(doc.waypoints[0].cmt, Some("keep"))
    assert_eq(doc.tracks[0].cmt, Some("keep"))
    assert_eq(doc.routes[0].cmt, Some("keep"))
  }
}

///|
test "transform source spans preserve BOM CRLF supplementary text unknown fields and inherited extension namespaces" {
  let source = "<?xml version=\"1.0\"?>\r\n<gpx version=\"1.1\" creator=\"设备😀 &amp; 私人\" xmlns=\"http://www.topografix.com/GPX/1/1\" xmlns:x=\"urn:test\"><metadata><name>名字😀</name></metadata>\r\n<wpt lat=\"0\" lon=\"0\"/>\r\n<wpt lat=\"1\" lon=\"1\"><name>保留😀</name><custom flag=\"α\">未知 &amp; 😀</custom><extensions><x:data>😀</x:data></extensions></wpt></gpx>"
  let bytes = Bytes::from_array([0xEF, 0xBB, 0xBF]) + @utf8.encode(source)
  let data = @model.GpxInput::new("original.gpx", bytes)
  let opts = options([@model.MetadataName])
  let result = @redact.redact_gpx(data, opts, @model.default_input_limits()).unwrap()
  let expected = source
    .replace(old="<name>名字😀</name>", new="")
    .replace(old="<wpt lat=\"0\" lon=\"0\"/>", new="")
  assert_eq(
    result.bytes,
    Bytes::from_array([0xEF, 0xBB, 0xBF]) + @utf8.encode(expected),
  )
  assert_eq(data.bytes, bytes)
  assert_eq(parsed(result).waypoints[0].name, Some("保留😀"))
  assert_eq(
    @redact.redact_gpx(data, opts, @model.default_input_limits()).unwrap().bytes,
    result.bytes,
  )
}

///|
test "transform preserves GPX 1.0 unknown course speed and removes legacy selected fields" {
  let data = @model.GpxInput::new(
    "legacy.gpx",
    @utf8.encode(
      "<gpx version=\"1.0\" creator=\"old\" xmlns=\"http://www.topografix.com/GPX/1/0\"><name>remove</name><author>remove</author><email>a@b</email><url>https://example.invalid</url><urlname>remove</urlname><trk><trkseg><trkpt lat=\"1\" lon=\"1\"><time>2026-01-01T00:00:00Z</time><course>12.5</course><speed>3.25</speed></trkpt></trkseg></trk></gpx>",
    ),
  )
  let file = @redact.redact_gpx(
    data,
    options([
      @model.MetadataName,
      @model.AuthorName,
      @model.AuthorEmail,
      @model.Link,
      @model.PointTimestamp,
    ]),
    @model.default_input_limits(),
  ).unwrap()
  let source = @utf8.decode(file.bytes) catch { _ => fail("UTF-8") }
  assert_true(source.contains("version=\"1.0\""))
  assert_true(source.contains("<course>12.5</course><speed>3.25</speed>"))
  assert_false(source.contains("remove"))
  assert_false(source.contains("<time>"))
  assert_eq(parsed(file).tracks.length(), 1)
}

///|
test "transform refuses ambiguous unselected segment fields on splitting" {
  for
    extra in [
      "<extensions><x xmlns=\"urn:test\"/></extensions>", "<custom>unknown</custom>",
    ] {
    let data = input(
      "<trk><trkseg><trkpt lat=\"1\" lon=\"1\"/><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"2\" lon=\"2\"/>" +
      extra +
      "</trkseg></trk>",
    )
    match @redact.redact_gpx(data, options([]), @model.default_input_limits()) {
      Err(d) => assert_eq(d.code, "gpx.lossless_redaction_unsupported")
      Ok(_) => fail("ambiguous segment metadata must fail closed")
    }
  }
  let result = transformed(
    "<trk><trkseg><trkpt lat=\"1\" lon=\"1\"/><trkpt lat=\"0\" lon=\"0\"/><trkpt lat=\"2\" lon=\"2\"/><extensions><x xmlns=\"urn:test\"/></extensions></trkseg></trk>",
    [@model.Extensions],
  )
  assert_eq(parsed(result).tracks[0].segments.length(), 2)
}

///|
test "transform inherits guarded parser failures with safe diagnostics" {
  for
    source in [
      "<!DOCTYPE gpx><gpx/>", "<gpx>", "<gpx version=\"1.1\" creator=\"SECRET\" xmlns=\"http://www.topografix.com/GPX/1/1\"><wpt lat=\"999\" lon=\"0\"/></gpx>",
    ] {
    match
      @redact.redact_gpx(
        @model.GpxInput::new("secret.gpx", @utf8.encode(source)),
        options([]),
        @model.default_input_limits(),
      ) {
      Err(d) => {
        assert_false(d.to_string().contains("SECRET"))
        assert_false(d.to_string().contains("999"))
        assert_false(d.to_string().contains("secret.gpx"))
      }
      Ok(_) => fail("invalid input")
    }
  }
}

///|
test "transform preserves unselected fields on originally empty segments of retained tracks" {
  let body = "<trk><trkseg><extensions><x xmlns=\"urn:test\">keep</x></extensions></trkseg><trkseg><trkpt lat=\"1\" lon=\"1\"/></trkseg></trk>"
  let result = transformed(body, [])
  let original = @gpx.parse_input(input(body), @model.default_input_limits()).unwrap()
  assert_eq(parsed(result), original)
}

///|
test "transform preserves every supported point field and opaque extension content" {
  let body = "<metadata><name>remove</name><desc>keep</desc><bounds minlat=\"0\" minlon=\"0\" maxlat=\"10\" maxlon=\"10\"/></metadata><wpt lat=\"1.123456789\" lon=\"2.987654321\"><ele>100.125</ele><time>2026-01-01T00:00:00+08:00</time><magvar>12.5</magvar><geoidheight>-2.5</geoidheight><name>keep</name><cmt>keep</cmt><desc>keep</desc><src>keep</src><link href=\"https://example.invalid/?x=1&amp;y=2\"><text>keep</text><type>text/html</type></link><sym>keep</sym><type>keep</type><fix>3d</fix><sat>5</sat><hdop>1.5</hdop><vdop>2.5</vdop><pdop>3.5</pdop><ageofdgpsdata>4.5</ageofdgpsdata><dgpsid>15</dgpsid><extensions><payload xmlns=\"urn:test\"><name>keep</name><time>keep</time><extensions>keep</extensions><![CDATA[😀 & raw]]></payload></extensions></wpt><rte><name>keep</name><cmt>keep</cmt><desc>keep</desc><src>keep</src><link href=\"https://example.invalid\"/><number>7</number><type>keep</type><extensions><x xmlns=\"urn:test\"/></extensions><rtept lat=\"3\" lon=\"3\"/></rte><trk><name>keep</name><cmt>keep</cmt><desc>keep</desc><src>keep</src><link href=\"https://example.invalid\"/><number>8</number><type>keep</type><extensions><x xmlns=\"urn:test\"/></extensions><trkseg><trkpt lat=\"4\" lon=\"4\"/><extensions><x xmlns=\"urn:test\"/></extensions></trkseg></trk>"
  let file = transformed(body, [@model.MetadataName])
  assert_eq(
    file.bytes,
    input(body.replace(old="<name>remove</name>", new="")).bytes,
  )
  assert_eq(
    parsed(file).waypoints[0],
    @gpx.parse_input(input(body), @model.default_input_limits()).unwrap().waypoints[0],
  )
}

///|
test "transform guards source and generated candidate size limits" {
  let data = input("<wpt lat=\"1\" lon=\"1\"/>")
  let tiny = @model.make_input_limits(16, 1, 1, 16, 64, 100).unwrap()
  match @redact.redact_gpx(data, options([]), tiny) {
    Err(d) => assert_eq(d.code, @model.code_file_too_large)
    Ok(_) => fail("source limit")
  }
  let data = @model.GpxInput::new(
    "tight.gpx",
    @utf8.encode(
      "<gpx version=\"1.1\" creator=\"\" xmlns=\"http://www.topografix.com/GPX/1/1\"><wpt lat=\"1\" lon=\"1\"/></gpx>",
    ),
  )
  let exact = @model.make_input_limits(
    data.bytes.length(),
    1,
    1,
    data.bytes.length(),
    64,
    100,
  ).unwrap()
  match @redact.redact_gpx(data, options([@model.Creator]), exact) {
    Err(d) => assert_eq(d.code, "gpx.lossless_redaction_unsupported")
    Ok(_) => fail("candidate limit")
  }
}
