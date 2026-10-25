///|
const TEST_DISTANCE_TOLERANCE_METERS : Double = 0.01

///|
fn geo_point(latitude : Double, longitude : Double) -> @model.GeoPoint {
  @model.make_geo_point(latitude, longitude).unwrap()
}

///|
fn distance_is_near(actual : Double, expected : Double) -> Bool {
  (actual - expected).abs() <= TEST_DISTANCE_TOLERANCE_METERS
}

///|
fn center_of(points : Array[@model.GeoPoint]) -> @model.GeoPoint {
  @geo.spherical_mean(points).unwrap()
}

///|
test "distance is zero for identical coordinates" {
  let point = geo_point(37.7749, -122.4194)
  assert_true(distance_is_near(@geo.distance_m(point, point), 0.0))
}

///|
test "distance matches a short equatorial reference displacement" {
  let west = geo_point(0.0, 0.0)
  let east = geo_point(0.0, 0.001)
  assert_true(distance_is_near(@geo.distance_m(west, east), 111.1950802))
}

///|
test "distance takes the short path across the antimeridian" {
  let east = geo_point(0.0, 179.999)
  let west = geo_point(0.0, -179.999)
  assert_true(distance_is_near(@geo.distance_m(east, west), 222.3901605))
  assert_true(
    distance_is_near(@geo.distance_m(east, west), @geo.distance_m(west, east)),
  )
}

///|
test "distance remains accurate at high latitude and at the poles" {
  let north_60 = geo_point(60.0, 0.0)
  let east_60 = geo_point(60.0, 1.0)
  assert_true(
    distance_is_near(@geo.distance_m(north_60, east_60), 55_597.0108649),
  )

  let north_pole_a = geo_point(90.0, 0.0)
  let north_pole_b = geo_point(90.0, 120.0)
  assert_true(
    distance_is_near(@geo.distance_m(north_pole_a, north_pole_b), 0.0),
  )
  assert_true(
    distance_is_near(
      @geo.distance_m(north_pole_a, geo_point(89.0, 0.0)),
      111_195.0802335,
    ),
  )
}

///|
test "distance is symmetric and never negative" {
  let first = geo_point(-22.4, 143.1)
  let second = geo_point(61.3, -48.6)
  let forward = @geo.distance_m(first, second)
  let reverse = @geo.distance_m(second, first)
  assert_true(forward >= 0.0)
  assert_true(distance_is_near(forward, reverse))
}

///|
test "radius comparison is inclusive at the boundary within the documented tolerance" {
  let start = geo_point(0.0, 0.0)
  let boundary = geo_point(0.001, 0.0)
  let radius = @geo.distance_m(start, boundary)
  let tolerance_degrees = TEST_DISTANCE_TOLERANCE_METERS /
    6_371_008.8 *
    180.0 /
    3.141592653589793
  let just_inside = geo_point(0.001 - tolerance_degrees, 0.0)
  let just_outside = geo_point(0.001 + tolerance_degrees, 0.0)
  assert_true(@geo.distance_m(start, just_inside) <= radius)
  assert_true(@geo.distance_m(start, boundary) <= radius)
  assert_true(@geo.distance_m(start, just_outside) > radius)
}

///|
test "spherical mean preserves an identical point" {
  let point = geo_point(-33.8688, 151.2093)
  let center = center_of([point, point, point])
  assert_true((center.latitude - point.latitude).abs() < 1.0e-10)
  assert_true((center.longitude - point.longitude).abs() < 1.0e-10)
}

///|
test "spherical mean centers a cluster across the antimeridian" {
  let center = center_of([geo_point(0.0, 179.9), geo_point(0.0, -179.9)])
  assert_true(center.latitude.abs() < 1.0e-10)
  assert_true((center.longitude.abs() - 180.0).abs() < 1.0e-8)
}

///|
test "spherical mean handles a high-latitude cluster" {
  let center = center_of([geo_point(80.0, 0.0), geo_point(80.0, 90.0)])
  assert_true((center.latitude - 82.8929239).abs() < 0.001)
  assert_true((center.longitude - 45.0).abs() < 1.0e-8)
}

///|
test "spherical mean rejects empty and antipodal inputs" {
  match @geo.spherical_mean([]) {
    Ok(_) => fail("an empty point set has no spherical center")
    Err(diagnostic) => assert_eq(diagnostic.code, @model.code_undefined_center)
  }
  match @geo.spherical_mean([geo_point(0.0, 0.0), geo_point(0.0, 180.0)]) {
    Ok(_) => fail("an antipodal pair has no unique spherical center")
    Err(diagnostic) => assert_eq(diagnostic.code, @model.code_undefined_center)
  }
  match
    @geo.spherical_mean([geo_point(0.0, 0.0), geo_point(0.0, 179.999999999999)]) {
    Ok(_) => fail("an unstable near-antipodal mean should be rejected")
    Err(diagnostic) => assert_eq(diagnostic.code, @model.code_undefined_center)
  }
}

///|
test "maximum distance from a center returns the farthest point distance" {
  let center = geo_point(0.0, 0.5)
  let points = [geo_point(0.0, 0.0), geo_point(0.0, 1.0)]
  assert_true(
    distance_is_near(
      @geo.max_distance_from_center(points, center),
      55_597.5401168,
    ),
  )
}
