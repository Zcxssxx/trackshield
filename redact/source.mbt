///|
/// xml 0.4.1 spans are UTF-16 string offsets, never byte offsets.
priv struct SourceElement {
  element : @xml.XmlElement
  start : Int32
  open_end : Int32
  mut end : Int32
  children : Array[SourceElement]
}

///|
priv struct Rewritten {
  text : String
  points : Int32
  segments : Int32
}

///|
fn source_tree(source : String) -> Result[SourceElement, Unit] {
  let events = @xml.Reader::from_string(source).read_events_until_eof() catch {
    _ => return Err(())
  }
  let stack : Array[SourceElement] = []
  let mut root : SourceElement? = None
  for event in events {
    match event.kind {
      Start(element) | Empty(element) => {
        let node : SourceElement = {
          element,
          start: event.span.start.offset,
          open_end: event.span.end.offset,
          end: event.span.end.offset,
          children: [],
        }
        if stack.length() > 0 {
          stack[stack.length() - 1].children.push(node)
        } else {
          root = Some(node)
        }
        if event.kind is Start(_) {
          stack.push(node)
        }
      }
      End(_) => stack.pop().unwrap().end = event.span.end.offset
      _ => ()
    }
  }
  match root {
    Some(root) => Ok(root)
    None => Err(())
  }
}

///|
fn source_point_inside(
  node : SourceElement,
  options : @model.RedactionOptions,
) -> Bool {
  let lat = @moongpx.Latitude::from_string(node.element.get("lat").unwrap()).unwrap()
  let lon = @moongpx.Longitude::from_string(node.element.get("lon").unwrap()).unwrap()
  let point = @model.make_geo_point(lat.to_double(), lon.to_double()).unwrap()
  @geo.distance_m(options.center, point) <= options.radius_m
}

///|
fn rewrite_element(
  source : String,
  node : SourceElement,
  parent : String,
  options : @model.RedactionOptions,
) -> Result[Rewritten, Unit] {
  let name = node.element.name
  let context = element_context(parent, name)
  if remove_element(parent, name, options) {
    return Ok({ text: "", points: 0, segments: 0, })
  }
  let is_point = context == "point"
  if is_point && source_point_inside(node, options) {
    return Ok({ text: "", points: 0, segments: 0, })
  }
  if context == "unknown" || name == "extensions" {
    return Ok({
      text: source[node.start:node.end].to_owned(),
      points: 0,
      segments: 0,
    })
  }
  let opening = if context == "gpx" && selected(options, @model.Creator) {
    let creator = node.element.attributes.filter(fn(a) { a.name == "creator" })[0]
    source[node.start:creator.value_span.start.offset].to_owned() +
    "TrackShield" +
    source[creator.value_span.end.offset:node.open_end].to_owned()
  } else {
    source[node.start:node.open_end].to_owned()
  }
  let chunks : Array[String] = [opening]
  let mut cursor = node.open_end
  let mut points = if is_point { 1 } else { 0 }
  let mut segments = 0
  let mut runs = 0
  let mut in_run = false
  for child in node.children {
    let result = match rewrite_element(source, child, context, options) {
      Ok(value) => value
      Err(_) => return Err(())
    }
    chunks.push(source[cursor:child.start].to_owned())
    if context == "segment" && child.element.name == "trkpt" {
      if result.points == 0 {
        in_run = false
      } else {
        if !in_run {
          if runs > 0 {
            chunks.push("</trkseg>" + opening)
          }
          runs += 1
        }
        in_run = true
      }
    }
    chunks.push(result.text)
    points += result.points
    segments += result.segments
    cursor = child.end
  }
  chunks.push(source[cursor:node.end].to_owned())
  if context == "segment" {
    // Splitting cannot assign opaque segment fields to runs without inventing
    // semantics. Namespace declarations alone may be copied to the new wrapper.
    if runs > 1 &&
      (
        node.element.attributes.any(fn(a) {
          a.name != "xmlns" && !a.name.has_prefix("xmlns:")
        }) ||
        node.children.any(fn(c) {
          c.element.name != "trkpt" &&
          !remove_element("segment", c.element.name, options)
        })
      ) {
      return Err(())
    }
    segments = runs
  }
  if (context == "track" || context == "route" || context == "segment") &&
    points == 0 {
    // A pre-existing empty segment can still own unselected fields. Preserve
    // those fields when another segment keeps the parent track alive.
    if context == "segment" &&
      !node.children.any(fn(c) { c.element.name == "trkpt" }) &&
      (
        node.children.any(fn(c) {
          !remove_element("segment", c.element.name, options)
        }) ||
        node.element.attributes.any(fn(a) {
          a.name != "xmlns" && !a.name.has_prefix("xmlns:")
        })
      ) {
      return Ok({ text: chunks.join(""), points: 0, segments: 1, })
    }
    return Ok({ text: "", points: 0, segments: 0, })
  }
  Ok({ text: chunks.join(""), points, segments, })
}
