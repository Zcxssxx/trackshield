///|
/// Category membership is boolean: duplicate choices never multiply counts.
fn selected(
  options : @model.RedactionOptions,
  category : @model.MetadataCategory,
) -> Bool {
  options.remove_metadata.any(fn(value) {
    value.to_string() == category.to_string()
  })
}

///|
fn[T] field_count(
  options : @model.RedactionOptions,
  category : @model.MetadataCategory,
  value : T?,
) -> Int32 {
  if value is Some(_) && selected(options, category) {
    1
  } else {
    0
  }
}

///|
fn link_count(
  options : @model.RedactionOptions,
  links : Array[@moongpx.Link],
) -> Int32 {
  if selected(options, @model.Link) {
    links.length()
  } else {
    0
  }
}

///|
fn point_metadata(
  options : @model.RedactionOptions,
  point : @moongpx.Waypoint,
) -> Int32 {
  field_count(options, @model.WaypointName, point.name) +
  field_count(options, @model.WaypointDescription, point.desc) +
  field_count(options, @model.PointTimestamp, point.time) +
  field_count(options, @model.Extensions, point.extensions) +
  link_count(options, point.links)
}

///|
fn document_metadata(
  options : @model.RedactionOptions,
  document : @moongpx.Gpx,
) -> Int32 {
  let mut count = if selected(options, @model.Creator) { 1 } else { 0 }
  count += field_count(options, @model.Extensions, document.extensions)
  if document.metadata is Some(metadata) {
    count += field_count(options, @model.MetadataName, metadata.name)
    count += field_count(options, @model.MetadataDescription, metadata.desc)
    count += field_count(options, @model.Extensions, metadata.extensions)
    count += link_count(options, metadata.links)
    if metadata.author is Some(author) {
      count += field_count(options, @model.AuthorName, author.name)
      count += field_count(options, @model.AuthorEmail, author.email)
      count += field_count(options, @model.Link, author.link)
    }
  }
  count
}

///|
fn inside_circle(
  point : @moongpx.Waypoint,
  options : @model.RedactionOptions,
) -> Bool {
  let location = @model.make_geo_point(
    point.lat.to_double(),
    point.lon.to_double(),
  ).unwrap()
  @geo.distance_m(options.center, location) <= options.radius_m
}
