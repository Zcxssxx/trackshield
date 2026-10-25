///|
fn record_optional_metadata(
  findings : Array[@model.MetadataFinding],
  source_path : String,
  category : @model.MetadataCategory,
  item_ordinal : Int32,
  value : String?,
) -> Unit {
  match value {
    Some(_) =>
      findings.push(
        @model.make_metadata_finding(source_path, category, item_ordinal, 1),
      )
    None => ()
  }
}

///|
fn record_extension(
  findings : Array[@model.MetadataFinding],
  source_path : String,
  item_ordinal : Int32,
  extension : String?,
) -> Unit {
  match extension {
    Some(_) =>
      findings.push(
        @model.make_metadata_finding(
          source_path,
          @model.MetadataCategory::Extensions,
          item_ordinal,
          1,
        ),
      )
    None => ()
  }
}

///|
fn record_links(
  findings : Array[@model.MetadataFinding],
  source_path : String,
  links : Array[@moongpx.Link],
  next_ordinal : Int32,
) -> Int32 {
  let mut ordinal = next_ordinal
  for _ in links {
    ordinal += 1
    findings.push(
      @model.make_metadata_finding(
        source_path,
        @model.MetadataCategory::Link,
        ordinal,
        1,
      ),
    )
  }
  ordinal
}

///|
fn record_waypoint_metadata(
  findings : Array[@model.MetadataFinding],
  source_path : String,
  point : @moongpx.Waypoint,
  point_ordinal : Int32,
  link_ordinal : Int32,
  extension_ordinal : Int32,
) -> (Int32, Int32) {
  record_optional_metadata(
    findings,
    source_path,
    @model.MetadataCategory::WaypointName,
    point_ordinal,
    point.name,
  )
  record_optional_metadata(
    findings,
    source_path,
    @model.MetadataCategory::WaypointDescription,
    point_ordinal,
    point.desc,
  )
  record_optional_metadata(
    findings,
    source_path,
    @model.MetadataCategory::PointTimestamp,
    point_ordinal,
    point.time,
  )
  let next_link_ordinal = record_links(
    findings,
    source_path,
    point.links,
    link_ordinal,
  )
  let mut next_extension_ordinal = extension_ordinal
  record_extension(
    findings,
    source_path,
    next_extension_ordinal + 1,
    point.extensions,
  )
  if point.extensions is Some(_) {
    next_extension_ordinal += 1
  }
  (next_link_ordinal, next_extension_ordinal)
}

///|
fn extract_metadata(
  source_path : String,
  document : @moongpx.Gpx,
) -> Array[@model.MetadataFinding] {
  let findings : Array[@model.MetadataFinding] = []
  let mut link_ordinal = 0
  let mut extension_ordinal = 0
  let mut point_ordinal = 0

  findings.push(
    @model.make_metadata_finding(
      source_path,
      @model.MetadataCategory::Creator,
      1,
      1,
    ),
  )
  record_extension(
    findings,
    source_path,
    extension_ordinal + 1,
    document.extensions,
  )
  if document.extensions is Some(_) {
    extension_ordinal += 1
  }

  match document.metadata {
    Some(metadata) => {
      record_optional_metadata(
        findings,
        source_path,
        @model.MetadataCategory::MetadataName,
        1,
        metadata.name,
      )
      record_optional_metadata(
        findings,
        source_path,
        @model.MetadataCategory::MetadataDescription,
        1,
        metadata.desc,
      )
      match metadata.author {
        Some(author) => {
          record_optional_metadata(
            findings,
            source_path,
            @model.MetadataCategory::AuthorName,
            1,
            author.name,
          )
          match author.email {
            Some(_) =>
              findings.push(
                @model.make_metadata_finding(
                  source_path,
                  @model.MetadataCategory::AuthorEmail,
                  1,
                  1,
                ),
              )
            None => ()
          }
          match author.link {
            Some(link) =>
              link_ordinal = record_links(
                findings,
                source_path,
                [link],
                link_ordinal,
              )
            None => ()
          }
        }
        None => ()
      }
      link_ordinal = record_links(
        findings,
        source_path,
        metadata.links,
        link_ordinal,
      )
      record_extension(
        findings,
        source_path,
        extension_ordinal + 1,
        metadata.extensions,
      )
      if metadata.extensions is Some(_) {
        extension_ordinal += 1
      }
    }
    None => ()
  }

  for waypoint in document.waypoints {
    point_ordinal += 1
    let (next_link, next_extension) = record_waypoint_metadata(
      findings, source_path, waypoint, point_ordinal, link_ordinal, extension_ordinal,
    )
    link_ordinal = next_link
    extension_ordinal = next_extension
  }

  let mut route_ordinal = 0
  for route in document.routes {
    route_ordinal += 1
    record_optional_metadata(
      findings,
      source_path,
      @model.MetadataCategory::RouteName,
      route_ordinal,
      route.name,
    )
    record_optional_metadata(
      findings,
      source_path,
      @model.MetadataCategory::RouteDescription,
      route_ordinal,
      route.desc,
    )
    link_ordinal = record_links(
      findings,
      source_path,
      route.links,
      link_ordinal,
    )
    record_extension(
      findings,
      source_path,
      extension_ordinal + 1,
      route.extensions,
    )
    if route.extensions is Some(_) {
      extension_ordinal += 1
    }
    for point in route.points {
      point_ordinal += 1
      let (next_link, next_extension) = record_waypoint_metadata(
        findings, source_path, point, point_ordinal, link_ordinal, extension_ordinal,
      )
      link_ordinal = next_link
      extension_ordinal = next_extension
    }
  }

  let mut track_ordinal = 0
  for track in document.tracks {
    track_ordinal += 1
    record_optional_metadata(
      findings,
      source_path,
      @model.MetadataCategory::TrackName,
      track_ordinal,
      track.name,
    )
    record_optional_metadata(
      findings,
      source_path,
      @model.MetadataCategory::TrackDescription,
      track_ordinal,
      track.desc,
    )
    link_ordinal = record_links(
      findings,
      source_path,
      track.links,
      link_ordinal,
    )
    record_extension(
      findings,
      source_path,
      extension_ordinal + 1,
      track.extensions,
    )
    if track.extensions is Some(_) {
      extension_ordinal += 1
    }
    for segment in track.segments {
      record_extension(
        findings,
        source_path,
        extension_ordinal + 1,
        segment.extensions,
      )
      if segment.extensions is Some(_) {
        extension_ordinal += 1
      }
      for point in segment.points {
        point_ordinal += 1
        let (next_link, next_extension) = record_waypoint_metadata(
          findings, source_path, point, point_ordinal, link_ordinal, extension_ordinal,
        )
        link_ordinal = next_link
        extension_ordinal = next_extension
      }
    }
  }

  findings
}
