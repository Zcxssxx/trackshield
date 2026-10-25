///|
const EARTH_RADIUS_METERS : Double = 6_371_008.8

///|
const DEGREES_TO_RADIANS : Double = 3.141592653589793 / 180.0

///|
const MINIMUM_BUCKET_WIDTH_METERS : Double = 0.001

///|
/// Group connected endpoint observations while keeping exact source identity
/// and stable evidence ordering independent from caller input order.
pub fn audit_collection(
  inspections : Array[@model.FileInspection],
  options : @model.AuditOptions,
) -> @model.AuditReport {
  let endpoints : Array[@model.EndpointObservation] = []
  let diagnostics : Array[@model.Diagnostic] = []
  for inspection in inspections {
    for diagnostic in inspection.diagnostics {
      diagnostics.push(diagnostic)
    }
    if inspection.analyzed {
      for endpoint in inspection.endpoints {
        let normalized_endpoint = @model.make_endpoint_observation(
          inspection.source_path,
          endpoint.track_ordinal,
          endpoint.kind,
          endpoint.observation_index,
          endpoint.point,
        )
        match invalid_coordinate_diagnostic(normalized_endpoint) {
          Some(diagnostic) => diagnostics.push(diagnostic)
          None => endpoints.push(normalized_endpoint)
        }
      }
    }
  }
  endpoints.sort_by(compare_endpoints)

  let endpoint_count = endpoints.length()
  let parents : Array[Int32] = []
  let ranks : Array[Int32] = []
  for index in 0..<endpoint_count {
    parents.push(index)
    ranks.push(0)
  }

  let grid : @hashmap.HashMap[String, Array[Int32]] = @hashmap.from_array([])
  let maximum_spherical_distance = 3.141592653589793 * EARTH_RADIUS_METERS
  let chord_angle = options.radius_m.min(maximum_spherical_distance) /
    (2.0 * EARTH_RADIUS_METERS)
  let chord_radius = 2.0 * EARTH_RADIUS_METERS * @math.sin(chord_angle)
  let bucket_width = (chord_radius * (1.0 + 1.0e-12)).max(
    MINIMUM_BUCKET_WIDTH_METERS,
  )
  for index in 0..<endpoint_count {
    let endpoint = endpoints[index]
    let (cell_x, cell_y, cell_z) = cell_for(endpoint.point, bucket_width)
    for offset_x in [-1, 0, 1] {
      for offset_y in [-1, 0, 1] {
        for offset_z in [-1, 0, 1] {
          let neighbor_key = bucket_key(
            cell_x + offset_x.to_int64(),
            cell_y + offset_y.to_int64(),
            cell_z + offset_z.to_int64(),
          )
          match grid.get(neighbor_key) {
            Some(neighbors) =>
              for neighbor_index in neighbors {
                if @geo.distance_m(
                    endpoint.point,
                    endpoints[neighbor_index].point,
                  ) <=
                  options.radius_m {
                  union_sets(parents, ranks, index, neighbor_index)
                }
              }
            None => ()
          }
        }
      }
    }
    let key = bucket_key(cell_x, cell_y, cell_z)
    match grid.get(key) {
      Some(bucket) => bucket.push(index)
      None => grid.set(key, [index])
    }
  }

  let component_indexes : Array[Array[Int32]] = []
  let component_by_root : @hashmap.HashMap[Int32, Int32] = @hashmap.from_array([])
  for index in 0..<endpoint_count {
    let root = find_root(parents, index)
    match component_by_root.get(root) {
      Some(component_index) => component_indexes[component_index].push(index)
      None => {
        let component_index = component_indexes.length()
        component_indexes.push([index])
        component_by_root.set(root, component_index)
      }
    }
  }

  let repeated_locations : Array[@model.RepeatedLocation] = []
  for indexes in component_indexes {
    let (distinct_file_count, distinct_track_count) = count_sources(
      indexes, endpoints,
    )
    if distinct_file_count >= options.min_distinct_files {
      let points : Array[@model.GeoPoint] = []
      let evidence : Array[@model.EndpointEvidence] = []
      for index in indexes {
        let endpoint = endpoints[index]
        points.push(endpoint.point)
        evidence.push(
          @model.make_endpoint_evidence(
            endpoint.source_path,
            endpoint.track_ordinal,
            endpoint.kind,
            endpoint.observation_index,
          ),
        )
      }
      let id = "location-" + (repeated_locations.length() + 1).to_string()
      match @geo.spherical_mean(points) {
        Ok(center) => {
          let max_distance = @geo.max_distance_from_center(points, center)
          let is_wide = max_distance > options.radius_m
          if is_wide {
            diagnostics.push(wide_component_diagnostic())
          }
          repeated_locations.push(
            @model.make_repeated_location(
              id,
              distinct_file_count,
              distinct_track_count,
              evidence,
              if options.include_coordinates {
                Some(center)
              } else {
                None
              },
              Some(max_distance),
              is_wide,
            ),
          )
        }
        Err(_) => {
          diagnostics.push(undefined_component_center_diagnostic())
          repeated_locations.push(
            @model.make_repeated_location(
              id,
              distinct_file_count,
              distinct_track_count,
              evidence,
              None,
              None,
              false,
            ),
          )
        }
      }
    }
  }

  diagnostics.sort_by(compare_diagnostics)
  let metadata_findings = aggregate_metadata_findings(inspections, diagnostics)
  @model.make_audit_report(
    options, repeated_locations, metadata_findings, diagnostics,
  )
}

///|
fn invalid_coordinate_diagnostic(
  endpoint : @model.EndpointObservation,
) -> @model.Diagnostic? {
  if !(endpoint.point.latitude >= -90.0 && endpoint.point.latitude <= 90.0) {
    Some(
      @model.Diagnostic::new(
        @model.code_invalid_latitude,
        @model.Error,
        endpoint.source_path,
        "latitude must be between -90 and 90 degrees",
      ),
    )
  } else if !(endpoint.point.longitude >= -180.0 &&
    endpoint.point.longitude <= 180.0) {
    Some(
      @model.Diagnostic::new(
        @model.code_invalid_longitude,
        @model.Error,
        endpoint.source_path,
        "longitude must be between -180 and 180 degrees",
      ),
    )
  } else {
    None
  }
}

///|
fn compare_endpoints(
  left : @model.EndpointObservation,
  right : @model.EndpointObservation,
) -> Int32 {
  let path_order = left.source_path.compare(right.source_path)
  if path_order != 0 {
    return path_order
  }
  if left.track_ordinal != right.track_ordinal {
    return left.track_ordinal.compare(right.track_ordinal)
  }
  let kind_order = endpoint_kind_order(left.kind) -
    endpoint_kind_order(right.kind)
  if kind_order != 0 {
    return kind_order
  }
  if left.observation_index != right.observation_index {
    return left.observation_index.compare(right.observation_index)
  }
  let latitude_order = compare_doubles(
    left.point.latitude,
    right.point.latitude,
  )
  if latitude_order != 0 {
    return latitude_order
  }
  compare_doubles(left.point.longitude, right.point.longitude)
}

///|
fn endpoint_kind_order(kind : @model.EndpointKind) -> Int32 {
  match kind {
    Start => 0
    End => 1
  }
}

///|
fn compare_doubles(left : Double, right : Double) -> Int32 {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn cell_for(
  point : @model.GeoPoint,
  bucket_width : Double,
) -> (Int64, Int64, Int64) {
  let latitude = point.latitude * DEGREES_TO_RADIANS
  let longitude = point.longitude * DEGREES_TO_RADIANS
  let cos_latitude = @math.cos(latitude)
  let x = EARTH_RADIUS_METERS * cos_latitude * @math.cos(longitude)
  let y = EARTH_RADIUS_METERS * cos_latitude * @math.sin(longitude)
  let z = EARTH_RADIUS_METERS * @math.sin(latitude)
  (
    (x / bucket_width).floor().to_int64(),
    (y / bucket_width).floor().to_int64(),
    (z / bucket_width).floor().to_int64(),
  )
}

///|
fn bucket_key(x : Int64, y : Int64, z : Int64) -> String {
  x.to_string() + "," + y.to_string() + "," + z.to_string()
}

///|
fn find_root(parents : Array[Int32], index : Int32) -> Int32 {
  let mut root = index
  while parents[root] != root {
    root = parents[root]
  }
  let mut current = index
  while parents[current] != current {
    let next = parents[current]
    parents[current] = root
    current = next
  }
  root
}

///|
fn union_sets(
  parents : Array[Int32],
  ranks : Array[Int32],
  left : Int32,
  right : Int32,
) -> Unit {
  let left_root = find_root(parents, left)
  let right_root = find_root(parents, right)
  if left_root != right_root {
    if ranks[left_root] < ranks[right_root] {
      parents[left_root] = right_root
    } else if ranks[left_root] > ranks[right_root] {
      parents[right_root] = left_root
    } else {
      parents[right_root] = left_root
      ranks[left_root] += 1
    }
  }
}

///|
fn count_sources(
  indexes : Array[Int32],
  endpoints : Array[@model.EndpointObservation],
) -> (Int32, Int32) {
  let mut file_count = 0
  let mut track_count = 0
  let mut previous_path : String? = None
  let mut previous_track_path : String? = None
  let mut previous_track_ordinal = 0
  for index in indexes {
    let endpoint = endpoints[index]
    if previous_path is None || previous_path.unwrap() != endpoint.source_path {
      file_count += 1
      previous_path = Some(endpoint.source_path)
    }
    if previous_track_path is None ||
      previous_track_path.unwrap() != endpoint.source_path ||
      previous_track_ordinal != endpoint.track_ordinal {
      track_count += 1
      previous_track_path = Some(endpoint.source_path)
      previous_track_ordinal = endpoint.track_ordinal
    }
  }
  (file_count, track_count)
}

///|
fn wide_component_diagnostic() -> @model.Diagnostic {
  @model.Diagnostic::new(
    @model.code_wide_endpoint_component,
    @model.Warning,
    "",
    "a transitive endpoint component extends beyond the configured radius",
  )
}

///|
fn undefined_component_center_diagnostic() -> @model.Diagnostic {
  @model.Diagnostic::new(
    @model.code_undefined_center,
    @model.Warning,
    "",
    "a stable center cannot be calculated for this endpoint component",
  )
}

///|
fn compare_diagnostics(
  left : @model.Diagnostic,
  right : @model.Diagnostic,
) -> Int32 {
  let path_order = left.path.compare(right.path)
  if path_order != 0 {
    return path_order
  }
  let code_order = left.code.compare(right.code)
  if code_order != 0 {
    return code_order
  }
  let severity_order = left.severity
    .to_string()
    .compare(right.severity.to_string())
  if severity_order != 0 {
    return severity_order
  }
  left.message.compare(right.message)
}
