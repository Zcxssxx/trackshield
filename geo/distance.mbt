///|
const MEAN_EARTH_RADIUS_METERS : Double = 6_371_008.8

///|
const DEGREES_TO_RADIANS : Double = 3.141592653589793 / 180.0

///|
fn normalize_longitude_delta_degrees(delta : Double) -> Double {
  if delta > 180.0 {
    delta - 360.0
  } else if delta < -180.0 {
    delta + 360.0
  } else {
    delta
  }
}

///|
/// Return the great-circle distance in metres using the mean Earth radius.
/// Longitude differences use the shortest path across the antimeridian.
pub fn distance_m(a : @model.GeoPoint, b : @model.GeoPoint) -> Double {
  let latitude_a = a.latitude * DEGREES_TO_RADIANS
  let latitude_b = b.latitude * DEGREES_TO_RADIANS
  let delta_latitude = (b.latitude - a.latitude) * DEGREES_TO_RADIANS
  let delta_longitude = normalize_longitude_delta_degrees(
      b.longitude - a.longitude,
    ) *
    DEGREES_TO_RADIANS
  let sin_half_latitude = @math.sin(delta_latitude / 2.0)
  let sin_half_longitude = @math.sin(delta_longitude / 2.0)
  let haversine = sin_half_latitude * sin_half_latitude +
    @math.cos(latitude_a) *
    @math.cos(latitude_b) *
    sin_half_longitude *
    sin_half_longitude
  let bounded_haversine = if haversine < 0.0 {
    0.0
  } else if haversine > 1.0 {
    1.0
  } else {
    haversine
  }
  let central_angle = 2.0 *
    @math.atan2(bounded_haversine.sqrt(), (1.0 - bounded_haversine).sqrt())
  MEAN_EARTH_RADIUS_METERS * central_angle
}
