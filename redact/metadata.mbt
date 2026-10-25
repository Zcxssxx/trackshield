///|
/// Unknown subtrees and extension payloads remain opaque.
fn element_context(parent : String, name : String) -> String {
  match (parent, name) {
    ("", "gpx") => "gpx"
    ("gpx", "metadata") => "metadata"
    ("gpx", "trk") => "track"
    ("gpx", "rte") => "route"
    ("gpx", "wpt") | ("route", "rtept") | ("segment", "trkpt") => "point"
    ("track", "trkseg") => "segment"
    ("metadata", "author") => "author"
    _ => "unknown"
  }
}

///|
fn remove_element(
  parent : String,
  name : String,
  options : @model.RedactionOptions,
) -> Bool {
  let category = match (parent, name) {
    ("gpx", "name") | ("metadata", "name") => Some(@model.MetadataName)
    ("gpx", "desc") | ("metadata", "desc") => Some(@model.MetadataDescription)
    ("gpx", "author") | ("author", "name") => Some(@model.AuthorName)
    ("gpx", "email") | ("author", "email") => Some(@model.AuthorEmail)
    ("track", "name") => Some(@model.TrackName)
    ("track", "desc") => Some(@model.TrackDescription)
    ("route", "name") => Some(@model.RouteName)
    ("route", "desc") => Some(@model.RouteDescription)
    ("point", "name") => Some(@model.WaypointName)
    ("point", "desc") => Some(@model.WaypointDescription)
    ("point", "time") => Some(@model.PointTimestamp)
    (
      "gpx"
      | "metadata"
      | "author"
      | "track"
      | "route"
      | "point",
      "link"
      | "url"
      | "urlname",
    ) => Some(@model.Link)
    ("gpx" | "metadata" | "track" | "route" | "segment" | "point", "extensions") =>
      Some(@model.Extensions)
    _ => None
  }
  match category {
    Some(category) => selected(options, category)
    None => false
  }
}
