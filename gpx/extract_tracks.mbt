///|
fn count_document_points(document : @moongpx.Gpx) -> Int32 {
  let mut count = document.waypoints.length()
  for route in document.routes {
    count += route.points.length()
  }
  for track in document.tracks {
    for segment in track.segments {
      count += segment.points.length()
    }
  }
  count
}

///|
fn append_track_endpoints(
  source_path : String,
  track : @moongpx.Track,
  track_ordinal : Int32,
  next_observation_index : Int32,
  endpoints : Array[@model.EndpointObservation],
) -> Int32 {
  let mut first_point : @moongpx.Waypoint? = None
  let mut last_point : @moongpx.Waypoint? = None
  for segment in track.segments {
    if segment.points.length() > 0 {
      if first_point is None {
        first_point = Some(segment.points[0])
      }
      last_point = Some(segment.points[segment.points.length() - 1])
    }
  }

  let mut observation_index = next_observation_index
  match (first_point, last_point) {
    (Some(first), Some(last)) => {
      let start_point = @model.make_geo_point(
        first.lat.to_double(),
        first.lon.to_double(),
      ).unwrap()
      let end_point = @model.make_geo_point(
        last.lat.to_double(),
        last.lon.to_double(),
      ).unwrap()
      endpoints.push(
        @model.make_endpoint_observation(
          source_path,
          track_ordinal,
          @model.EndpointKind::Start,
          observation_index,
          start_point,
        ),
      )
      observation_index += 1
      endpoints.push(
        @model.make_endpoint_observation(
          source_path,
          track_ordinal,
          @model.EndpointKind::End,
          observation_index,
          end_point,
        ),
      )
      observation_index += 1
    }
    (None, None) => ()
    _ => ()
  }
  observation_index
}

///|
fn extract_track_endpoints(
  source_path : String,
  document : @moongpx.Gpx,
) -> Array[@model.EndpointObservation] {
  let endpoints : Array[@model.EndpointObservation] = []
  let mut observation_index = 0
  let mut track_ordinal = 0
  for track in document.tracks {
    track_ordinal += 1
    observation_index = append_track_endpoints(
      source_path, track, track_ordinal, observation_index, endpoints,
    )
  }
  endpoints
}
