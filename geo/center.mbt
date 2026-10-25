///|
/// Compute the normalized 3D resultant of a point set before converting it
/// back to latitude and longitude. Antipodal and near-antipodal sets have no
/// stable spherical mean and return a diagnostic instead of an arbitrary point.
pub fn spherical_mean(
  points : Array[@model.GeoPoint],
) -> Result[@model.GeoPoint, @model.Diagnostic] {
  if points.length() == 0 {
    return Err(undefined_center())
  }

  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut sum_z = 0.0
  for point in points {
    let latitude = point.latitude * DEGREES_TO_RADIANS
    let longitude = point.longitude * DEGREES_TO_RADIANS
    let latitude_cosine = @math.cos(latitude)
    sum_x += latitude_cosine * @math.cos(longitude)
    sum_y += latitude_cosine * @math.sin(longitude)
    sum_z += @math.sin(latitude)
  }

  let norm = (sum_x * sum_x + sum_y * sum_y + sum_z * sum_z).sqrt()
  let stability_floor = points.length().to_double() * 1.0e-12
  if norm <= stability_floor {
    return Err(undefined_center())
  }

  let horizontal_norm = (sum_x * sum_x + sum_y * sum_y).sqrt()
  let latitude = @math.atan2(sum_z, horizontal_norm) / DEGREES_TO_RADIANS
  let longitude = if horizontal_norm <= norm * 1.0e-12 {
    0.0
  } else {
    @math.atan2(sum_y, sum_x) / DEGREES_TO_RADIANS
  }
  match @model.make_geo_point(latitude, longitude) {
    Ok(center) => Ok(center)
    Err(_) => Err(undefined_center())
  }
}

///|
/// Return the greatest great-circle distance from `center` to any point.
pub fn max_distance_from_center(
  points : Array[@model.GeoPoint],
  center : @model.GeoPoint,
) -> Double {
  let mut maximum = 0.0
  for point in points {
    let distance = distance_m(point, center)
    if distance > maximum {
      maximum = distance
    }
  }
  maximum
}

///|
fn undefined_center() -> @model.Diagnostic {
  @model.Diagnostic::new(
    @model.code_undefined_center,
    @model.Error,
    "",
    "a stable spherical center cannot be defined for these points",
  )
}
