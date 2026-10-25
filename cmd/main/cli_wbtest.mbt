///|
test "CLI parser supplies bounded defaults and accepts validated overrides" {
  let defaults = parse_cli(["audit", "sample.gpx"]).unwrap()
  assert_eq(defaults.paths, ["sample.gpx"])
  assert_eq(defaults.radius_m, 500.0)
  assert_eq(defaults.min_distinct_files, 3)
  assert_eq(defaults.format, Text)
  assert_false(defaults.show_coordinates)
  assert_eq(defaults.limits.max_file_bytes, 32 * 1024 * 1024)
  assert_eq(defaults.limits.max_points_per_file, 250_000)
  assert_eq(defaults.limits.max_files, 500)
  assert_eq(defaults.limits.max_total_bytes, 256 * 1024 * 1024)

  let configured = parse_cli([
    "audit", "a.gpx", "b.gpx", "--radius-m", "750.5", "--min-files", "2", "--format",
    "json", "--show-coordinates", "--max-file-bytes", "4096", "--max-points", "1000",
    "--max-files", "7", "--max-total-bytes", "8192",
  ]).unwrap()
  assert_eq(configured.paths, ["a.gpx", "b.gpx"])
  assert_eq(configured.radius_m, 750.5)
  assert_eq(configured.min_distinct_files, 2)
  assert_eq(configured.format, Json)
  assert_true(configured.show_coordinates)
  assert_eq(configured.limits.max_file_bytes, 4096)
  assert_eq(configured.limits.max_points_per_file, 1000)
  assert_eq(configured.limits.max_files, 7)
  assert_eq(configured.limits.max_total_bytes, 8192)
}

///|
test "runtime argument adapter removes the executable prefix" {
  assert_eq(cli_arguments(["trackshield.exe", "audit", "sample.gpx"]), [
    "audit", "sample.gpx",
  ])
  assert_eq(cli_arguments([]), [])
}

///|
test "CLI parser requires a path and rejects malformed non-positive limits" {
  assert_true(cli_rejected([]))
  assert_true(cli_rejected(["audit"]))

  for
    option in [
      "--max-file-bytes", "--max-points", "--max-files", "--max-total-bytes",
    ] {
    for value in ["bad", "0", "-1"] {
      assert_true(cli_rejected(["audit", "sample.gpx", option, value]))
    }
  }
  assert_true(cli_rejected(["audit", "sample.gpx", "--radius-m", "bad"]))
  assert_true(cli_rejected(["audit", "sample.gpx", "--radius-m", "-1"]))
  assert_true(cli_rejected(["audit", "sample.gpx", "--radius-m", "0"]))
  assert_true(cli_rejected(["audit", "sample.gpx", "--min-files", "0"]))
  assert_true(cli_rejected(["audit", "sample.gpx", "--min-files", "bad"]))
  assert_true(cli_rejected(["audit", "sample.gpx", "--min-files", "-1"]))
  assert_true(cli_rejected(["audit", "sample.gpx", "--format", "yaml"]))
  assert_true(
    cli_rejected([
      "audit", "sample.gpx", "--max-file-bytes", "8192", "--max-total-bytes", "4096",
    ]),
  )
}

///|
fn cli_rejected(argv : Array[String]) -> Bool {
  match parse_cli(argv) {
    Ok(_) => false
    Err(_) => true
  }
}

///|
async test "CLI help and usage errors use distinct output streams and statuses" {
  let help = run_cli(["--help"])
  assert_eq(help.exit_code, 0)
  assert_true(help.stdout.contains("trackshield"))
  assert_eq(help.stderr, "")

  let usage = run_cli(["unknown"])
  assert_eq(usage.exit_code, 2)
  assert_eq(usage.stdout, "")
  assert_true(usage.stderr.contains("audit"))
}

///|
fn cli_test_gpx() -> String {
  "<gpx version=\"1.1\" creator=\"fixture\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><trkseg><trkpt lat=\"5\" lon=\"6\"/></trkseg></trk></gpx>"
}

///|
fn cli_test_bytes(text : String) -> Bytes {
  let bytes : Array[Byte] = []
  for character in text {
    bytes.push(character.to_int().to_byte())
  }
  Bytes::from_array(bytes)
}

///|
async test "invalid and unsupported inputs return a partial JSON report" {
  let root = "_build/trackshield_cli_bad_inputs"
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(root, recursive=true)
  defer @fs.rmdir(root, recursive=true)
  let unsupported_path = root + "/notes.txt"
  let valid_path = root + "/valid.gpx"
  @fs.write_file(unsupported_path, cli_test_bytes("not GPX"))
  @fs.write_file(valid_path, cli_test_bytes(cli_test_gpx()))

  let missing = run_cli(["audit", root + "/missing.gpx", "--format", "json"])
  assert_eq(missing.exit_code, 1)
  assert_true(missing.stdout.contains("\"diagnostics\""))
  assert_true(missing.stderr.contains("input.path_unreadable"))
  assert_false(missing.stderr.contains("not GPX"))

  let unsupported = run_cli(["audit", unsupported_path, "--format", "json"])
  assert_eq(unsupported.exit_code, 1)
  assert_true(unsupported.stdout.contains("cli.unsupported_extension"))
  assert_true(unsupported.stderr.contains("cli.unsupported_extension"))
  assert_false(unsupported.stdout.contains("not GPX"))

  let partial = run_cli([
    "audit",
    valid_path,
    root + "/missing-too.gpx",
    "--format",
    "json",
  ])
  assert_eq(partial.exit_code, 1)
  assert_true(partial.stdout.contains("valid.gpx"))
  assert_true(partial.stdout.contains("input.path_unreadable"))
  assert_true(partial.stderr.contains("input.path_unreadable"))
  assert_false(partial.stderr.contains("fixture"))
}

///|
async test "bounded file reads return I/O failures instead of raising" {
  let root = "_build/trackshield_cli_read_failure"
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(root, recursive=true)
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/closed.gpx"
  @fs.write_file(path, cli_test_bytes(cli_test_gpx()))
  let file = @fs.open(path, mode=@fs.ReadOnly)
  file.close()

  let converted_to_result = try {
    match read_bounded_file(file, 1024) {
      Err(_) => true
      Ok(_) => false
    }
  } catch {
    _ => false
  } noraise {
    value => value
  }
  assert_true(converted_to_result)
}

///|
async test "empty directories are valid and nested traversal is repeatable" {
  let root = "_build/trackshield_cli_nested"
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(root + "/nested", recursive=true)
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/z.gpx", cli_test_bytes(cli_test_gpx()))
  @fs.write_file(root + "/nested/a.gpx", cli_test_bytes(cli_test_gpx()))

  let empty = run_cli(["audit", root + "/empty", "--format", "json"])
  assert_eq(empty.exit_code, 1)
  // A missing directory is an input error; an existing empty directory is a valid empty audit.
  @fs.mkdir(root + "/empty")
  let empty_result = run_cli(["audit", root + "/empty", "--format", "json"])
  assert_eq(empty_result.exit_code, 0)
  assert_true(empty_result.stdout.contains("\"repeated_locations\":[]"))

  let args = ["audit", root, "--min-files", "2", "--format", "json"]
  let first = run_cli(args)
  let second = run_cli(args)
  assert_eq(first.exit_code, 0)
  assert_eq(first.stdout, second.stdout)
  assert_true(first.stdout.contains("location-1"))
  assert_true(first.stdout.contains("nested/a.gpx"))
  assert_true(first.stdout.contains("z.gpx"))

  let alias_only_file = run_cli([
    "audit",
    root + "/nested/a.gpx",
    root + "/nested/./a.gpx",
    "--min-files",
    "2",
    "--format",
    "json",
  ])
  assert_true(alias_only_file.stdout.contains("\"repeated_locations\":[]"))

  let overlapping_roots = run_cli([
    "audit",
    root,
    root + "/nested/../z.gpx",
    "--min-files",
    "2",
    "--format",
    "json",
  ])
  assert_true(overlapping_roots.stdout.contains("\"distinct_file_count\":2"))

  let hidden = run_cli(["audit", root, "--min-files", "2", "--format", "json"])
  assert_true(hidden.stdout.contains("\"center\":null"))
  let visible = run_cli([
    "audit", root, "--min-files", "2", "--show-coordinates", "--format", "json",
  ])
  assert_true(visible.stdout.contains("\"center\":{\"latitude\":"))
}

///|
async test "directory traversal skips a linked directory and collection limits are exact" {
  let root = "_build/trackshield_cli_limits"
  let target = "_build/trackshield_cli_link_target"
  @fs.rmdir(root, recursive=true) catch {
    _ => ()
  }
  @fs.rmdir(target, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(root, recursive=true)
  @fs.mkdir(target, recursive=true)
  defer @fs.rmdir(root, recursive=true)
  defer @fs.rmdir(target, recursive=true)
  let fixture = cli_test_bytes(cli_test_gpx())
  let bytes_per_file = fixture.length()
  @fs.write_file(root + "/a.gpx", fixture)
  @fs.write_file(root + "/b.gpx", fixture)
  @fs.write_file(target + "/c.gpx", fixture)
  @fs.write_file(target + "/d.gpx", fixture)

  let absolute_target = @fs.realpath(target)
  let link_created = try {
    @fs.symlink(target=absolute_target, root + "/linked")
    true
  } catch {
    _ => false
  } noraise {
    value => value
  }
  assert_true(link_created)
  if link_created {
    let linked = run_cli(["audit", root, "--min-files", "2", "--format", "json"])
    assert_eq(linked.exit_code, 0)
    assert_true(linked.stdout.contains("location-1"))
    assert_true(linked.stderr.contains("input.link_skipped"))
    assert_false(linked.stdout.contains("linked/c.gpx"))
    assert_false(linked.stdout.contains("linked/d.gpx"))

    let linked_descendant = run_cli([
      "audit",
      root + "/linked/c.gpx",
      "--format",
      "json",
    ])
    assert_eq(linked_descendant.exit_code, 1)
    assert_true(linked_descendant.stdout.contains("input.link_skipped"))
    assert_true(linked_descendant.stdout.contains("\"metadata_findings\":[]"))

    let explicit_link = run_cli(["audit", root + "/linked", "--format", "json"])
    assert_eq(explicit_link.exit_code, 1)
    assert_true(explicit_link.stdout.contains("input.link_skipped"))
  }

  let exact_total = (bytes_per_file * 2).to_string()
  let exact = run_cli([
    "audit",
    root,
    "--max-files",
    "2",
    "--max-file-bytes",
    bytes_per_file.to_string(),
    "--max-total-bytes",
    exact_total,
    "--min-files",
    "2",
    "--format",
    "json",
  ])
  assert_eq(exact.exit_code, 0)
  assert_false(exact.stdout.contains("input.total_bytes_exceeded"))
  assert_false(exact.stdout.contains("input.file_limit_exceeded"))

  let one_file_over = run_cli([
    "audit",
    root + "/a.gpx",
    "--max-file-bytes",
    (bytes_per_file - 1).to_string(),
    "--format",
    "json",
  ])
  assert_eq(one_file_over.exit_code, 1)
  assert_true(one_file_over.stdout.contains("input.file_too_large"))
  assert_false(one_file_over.stdout.contains("gpx.parse_failed"))

  let over_total = (bytes_per_file * 2 - 1).to_string()
  let total_over = run_cli([
    "audit",
    root,
    "--max-file-bytes",
    bytes_per_file.to_string(),
    "--max-total-bytes",
    over_total,
    "--min-files",
    "2",
    "--format",
    "json",
  ])
  assert_eq(total_over.exit_code, 1)
  assert_true(total_over.stdout.contains("input.total_bytes_exceeded"))
  assert_false(total_over.stdout.contains("gpx.parse_failed"))

  let count_over = run_cli([
    "audit", root, "--max-files", "1", "--min-files", "2", "--format", "json",
  ])
  assert_eq(count_over.exit_code, 1)
  assert_true(count_over.stdout.contains("input.file_limit_exceeded"))
  assert_false(count_over.stdout.contains("gpx.parse_failed"))
}
