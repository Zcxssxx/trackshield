///|
/// Preview a caller-supplied circle without writing files or consulting audits.
/// Points include track points, route points, and standalone waypoints.
/// Segments count additional retained runs per original segment. Metadata counts
/// selected fields on retained structures, excluding fields lost with parents.
pub fn preview_redaction(
  input : @model.GpxInput,
  options : @model.RedactionOptions,
  limits : @model.InputLimits,
) -> @model.RedactionPreview {
  let document = match @gpx.parse_input(input, limits) {
    Ok(document) => document
    Err(diagnostics) =>
      return @model.make_redaction_preview(
        input.path,
        0,
        0,
        0,
        0,
        0,
        false,
        diagnostics,
      )
  }
  let mut points_removed = 0
  let mut segments_created = 0
  let mut routes_removed = 0
  let mut waypoints_removed = 0
  let mut metadata_fields_removed = document_metadata(options, document)
  let mut retained_points = 0
  let diagnostics : Array[@model.Diagnostic] = []
  for point in document.waypoints {
    if inside_circle(point, options) {
      points_removed += 1
      waypoints_removed += 1
    } else {
      retained_points += 1
      metadata_fields_removed += point_metadata(options, point)
    }
  }
  for route in document.routes {
    let mut retained = 0
    for point in route.points {
      if inside_circle(point, options) {
        points_removed += 1
      } else {
        retained += 1
        metadata_fields_removed += point_metadata(options, point)
      }
    }
    retained_points += retained
    if retained == 0 {
      routes_removed += 1
      diagnostics.push(
        @model.Diagnostic::new(
          "redact.empty_route",
          @model.Info,
          input.path,
          "an empty route would be omitted",
        ),
      )
    } else {
      metadata_fields_removed += field_count(
        options,
        @model.RouteName,
        route.name,
      )
      metadata_fields_removed += field_count(
        options,
        @model.RouteDescription,
        route.desc,
      )
      metadata_fields_removed += field_count(
        options,
        @model.Extensions,
        route.extensions,
      )
      metadata_fields_removed += link_count(options, route.links)
    }
  }
  for track in document.tracks {
    let mut track_retained = 0
    for segment in track.segments {
      let mut runs = 0
      let mut in_run = false
      for point in segment.points {
        if inside_circle(point, options) {
          points_removed += 1
          in_run = false
        } else {
          track_retained += 1
          metadata_fields_removed += point_metadata(options, point)
          if !in_run {
            runs += 1
          }
          in_run = true
        }
      }
      if runs > 0 {
        segments_created += runs - 1
        // Each segment's selected extension container is removed once even when
        // its retained points would be split into several output segments.
        metadata_fields_removed += field_count(
          options,
          @model.Extensions,
          segment.extensions,
        )
      }
    }
    retained_points += track_retained
    if track_retained > 0 {
      metadata_fields_removed += field_count(
        options,
        @model.TrackName,
        track.name,
      )
      metadata_fields_removed += field_count(
        options,
        @model.TrackDescription,
        track.desc,
      )
      metadata_fields_removed += field_count(
        options,
        @model.Extensions,
        track.extensions,
      )
      metadata_fields_removed += link_count(options, track.links)
    } else {
      diagnostics.push(
        @model.Diagnostic::new(
          "redact.empty_track",
          @model.Info,
          input.path,
          "an empty track would be omitted",
        ),
      )
    }
  }
  let output_would_be_empty = retained_points == 0
  if output_would_be_empty {
    diagnostics.push(
      @model.Diagnostic::new(
        "redact.empty_result",
        @model.Warning,
        input.path,
        "redaction would leave no track, route, or waypoint content",
      ),
    )
  }
  @model.make_redaction_preview(
    input.path,
    points_removed,
    segments_created,
    routes_removed,
    waypoints_removed,
    metadata_fields_removed,
    output_would_be_empty,
    diagnostics,
  )
}
