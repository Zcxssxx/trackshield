///|
fn redact_args(paths : Array[String], output? : String) -> Array[String] {
  let args = ["redact"]
  args.append(paths)
  args.append(["--center", "0,0", "--radius-m", "100"])
  if output is Some(path) {
    args.append(["--write", "--output-dir", path])
  }
  args
}

///|
async fn redact_fixture_root() -> String {
  let root = @fs.tmpdir(prefix="trackshield-redact-test")
  @fs.mkdir(root + "/inputs")
  @fs.write_file(root + "/inputs/a.gpx", cli_test_bytes(cli_test_gpx()))
  root
}

///|
async fn redact_test_listing(path : String) -> Array[String] {
  let names = @fs.readdir(path)
  names.sort_by((a, b) => a.lexical_compare(b))
  names
}

///|
async test "redact preview has no output or staging side effects" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let before = @fs.read_file(root + "/inputs/a.gpx").binary()
  let args = redact_args([root + "/inputs"])
  args.append(["--output-dir", root + "/missing-parent/export"])
  let outcome = run_cli(args)
  assert_eq(outcome.exit_code, 0)
  assert_true(
    outcome.stdout.contains("Preview: files=1 ready=1 failed=0 written=0"),
  )
  assert_true(outcome.stdout.contains("points_removed=0"))
  assert_true(outcome.stdout.contains("remain sensitive"))
  assert_eq(redact_test_listing(root), ["inputs"])
  assert_eq(@fs.read_file(root + "/inputs/a.gpx").binary(), before)
}

///|
async test "redact write validates exports and preserves original bytes" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let source = root + "/inputs/a.gpx"
  let before = @fs.read_file(source).binary()
  let args = redact_args([source], output=root + "/exports")
  args.append(["--remove-metadata", "creator,creator"])
  let outcome = run_cli(args)
  assert_eq(outcome.exit_code, 0)
  assert_true(
    outcome.stdout.contains("Write: files=1 ready=1 failed=0 written=1"),
  )
  assert_true(outcome.stdout.contains("/exports/a.gpx"))
  let exported = @fs.read_file(root + "/exports/a.gpx").binary()
  let inspection = @api.inspect_gpx(
    @model.GpxInput::new("export", exported),
    @api.default_input_limits(),
  )
  assert_false(has_errors(inspection.diagnostics))
  assert_true(
    @fs.read_file(root + "/exports/a.gpx").text().contains("TrackShield"),
  )
  assert_eq(@fs.read_file(source).binary(), before)
  assert_eq(redact_test_listing(root), ["exports", "inputs"])
}

///|
async test "redact rejects missing output and existing nested or aliased destinations" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let args = redact_args([root + "/inputs"])
  args.push("--write")
  assert_eq(run_cli(args).exit_code, 2)
  for
    output in [
      root + "/inputs",
      root + "/inputs/nested",
      root + "/inputs/../inputs/nested",
      root + "/missing-parent/new",
    ] {
    let outcome = run_cli(redact_args([root + "/inputs"], output~))
    assert_eq(outcome.exit_code, 2)
    assert_true(outcome.stderr.contains("output."))
  }
  @fs.mkdir(root + "/existing")
  @fs.write_file(root + "/existing/sentinel", b"unchanged")
  assert_eq(
    run_cli(redact_args([root + "/inputs"], output=root + "/existing")).exit_code,
    2,
  )
  assert_eq(@fs.read_file(root + "/existing/sentinel").binary(), b"unchanged")
  assert_eq(redact_test_listing(root), ["existing", "inputs"])
}

///|
async test "redact rejects derived basename collisions before staging" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/other")
  @fs.write_file(root + "/other/a.gpx", cli_test_bytes(cli_test_gpx()))
  let outcome = run_cli(
    redact_args([root + "/inputs", root + "/other"], output=root + "/exports"),
  )
  assert_eq(outcome.exit_code, 2)
  assert_true(outcome.stderr.contains("output.basename_collision"))
  assert_eq(redact_test_listing(root), ["inputs", "other"])
}

///|
async test "redact mixed valid invalid batch fails closed with private diagnostics" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(
    root + "/inputs/bad.gpx",
    b"<gpx>PRIVATE_SOURCE_SECRET</wrong>",
  )
  let outcome = run_cli(
    redact_args([root + "/inputs"], output=root + "/exports"),
  )
  assert_eq(outcome.exit_code, 2)
  assert_true(outcome.stdout.contains("files=2 ready=1 failed=1 written=0"))
  assert_true(outcome.stderr.contains(@api.code_invalid_xml))
  assert_true(outcome.stderr.contains("bad.gpx"))
  assert_false(
    (outcome.stdout + outcome.stderr).contains("PRIVATE_SOURCE_SECRET"),
  )
  assert_eq(redact_test_listing(root), ["inputs"])
}

///|
async test "redact refuses empty results and missing inputs without publication" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let args = [
    "redact",
    root + "/inputs",
    "--center",
    "5,6",
    "--radius-m",
    "100",
    "--write",
    "--output-dir",
    root + "/exports",
  ]
  let empty = run_cli(args)
  assert_eq(empty.exit_code, 2)
  assert_true(empty.stderr.contains("redact.empty_result"))
  let missing = run_cli(
    redact_args([root + "/missing.gpx"], output=root + "/exports"),
  )
  assert_eq(missing.exit_code, 2)
  assert_true(missing.stderr.contains("input.path_unreadable"))
  assert_eq(redact_test_listing(root), ["inputs"])
}

///|
async test "redact rejects reparse ancestors on inputs and destinations" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  @fs.symlink(target=@fs.realpath(root + "/inputs"), root + "/linked")
  for paths in [[root + "/linked/a.gpx"], [root]] {
    let outcome = run_cli(redact_args(paths, output=root + "/exports"))
    assert_eq(outcome.exit_code, 2)
    assert_true(outcome.stderr.contains("input.link_skipped"))
  }
  let output_link = run_cli(
    redact_args([root + "/inputs/a.gpx"], output=root + "/linked/export"),
  )
  assert_eq(output_link.exit_code, 2)
  assert_true(output_link.stderr.contains("output."))
  assert_false(@fs.exists(root + "/exports"))
  assert_false(@fs.exists(root + "/inputs/export"))
}

///|
async test "redact validates CLI options without echoing values" {
  for
    options in [
      [],
      ["--center", "0,0"],
      ["--center", "91,0", "--radius-m", "1"],
      ["--center", "0,NaN", "--radius-m", "1"],
      ["--center", "0,0", "--radius-m", "0"],
      ["--center", "0,0", "--radius-m", "Infinity"],
      [
        "--center", "0,0", "--radius-m", "1", "--remove-metadata", "PRIVATE_UNKNOWN",
      ],
      ["--center", "0,0", "--radius-m", "1", "--remove-metadata", "creator,"],
    ] {
    let args = ["redact", "file.gpx"]
    args.append(options)
    let outcome = run_cli(args)
    assert_eq(outcome.exit_code, 2)
    assert_false(outcome.stderr.contains("PRIVATE_UNKNOWN"))
  }
  let help = run_cli(["redact", "--help"])
  assert_eq(help.exit_code, 0)
  assert_true(help.stdout.contains("--center"))
}

///|
async test "redact link-only directory fails closed even with zero discovered files" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/only-links")
  @fs.symlink(
    target=@fs.realpath(root + "/inputs"),
    root + "/only-links/linked",
  )
  let preview = run_cli(redact_args([root + "/only-links"]))
  assert_eq(preview.exit_code, 2)
  let write = run_cli(
    redact_args([root + "/only-links"], output=root + "/exports"),
  )
  assert_eq(write.exit_code, 2)
  assert_false(@fs.exists(root + "/exports"))
}

///|
async test "redact portable path mapping rejects aliases and case collisions" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  for
    output in [
      root + "/export.",
      root + "/export ",
      root + "/CON",
      root + "/a:stream",
      "C:relative",
      "//?/C:/device",
      "//server/share/export",
    ] {
    let outcome = run_cli(redact_args([root + "/inputs"], output~))
    assert_eq(outcome.exit_code, 2)
    assert_true(outcome.stderr.contains("output.unsafe_path"))
  }
  @fs.mkdir(root + "/other")
  @fs.write_file(root + "/other/A.gpx", cli_test_bytes(cli_test_gpx()))
  let collision = run_cli(
    redact_args([root + "/inputs", root + "/other"], output=root + "/exports"),
  )
  assert_eq(collision.exit_code, 2)
  assert_true(collision.stderr.contains("output.basename_collision"))
  @fs.write_file(
    root + "/other/non portable.gpx",
    cli_test_bytes(cli_test_gpx()),
  )
  let rejected = run_cli(
    redact_args([root + "/other/non portable.gpx"], output=root + "/exports"),
  )
  assert_eq(rejected.exit_code, 2)
  assert_true(rejected.stderr.contains("output.unsafe_basename"))
  assert_false(@fs.exists(root + "/exports"))
}

///|
async test "redact exclusive staging and filesystem primitives never replace sentinels" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  @fs.mkdir(root + "/exports.trackshield-stage")
  @fs.write_file(
    root + "/exports.trackshield-stage/sentinel",
    b"stage-sentinel",
  )
  let outcome = run_cli(
    redact_args([root + "/inputs"], output=root + "/exports"),
  )
  assert_eq(outcome.exit_code, 2)
  assert_true(outcome.stderr.contains("output.write_failed"))
  assert_eq(
    @fs.read_file(root + "/exports.trackshield-stage/sentinel").binary(),
    b"stage-sentinel",
  )
  assert_false(@fs.exists(root + "/exports"))
  @fs.write_file(root + "/sentinel", b"original")
  let exclusive_failed = try {
    create_synced_file(root + "/sentinel", b"replacement")
    false
  } catch {
    _ => true
  } noraise {
    value => value
  }
  assert_true(exclusive_failed)
  assert_eq(@fs.read_file(root + "/sentinel").binary(), b"original")
  @fs.mkdir(root + "/old")
  @fs.mkdir(root + "/new")
  let rename_failed = try {
    @fs.rename(root + "/old", root + "/new", replace=false)
    false
  } catch {
    _ => true
  } noraise {
    value => value
  }
  assert_true(rename_failed)
  assert_true(@fs.exists(root + "/old"))
  assert_true(@fs.exists(root + "/new"))
}

///|
async test "redact staged validation refuses corrupt and unpublishable bytes" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let options = @api.make_redaction_options(
    @api.make_geo_point(0, 0).unwrap(),
    100,
    [],
  ).unwrap()
  let limits = @api.default_input_limits()
  let redacted = @api.redact_gpx(
    @model.GpxInput::new("fixture", cli_test_bytes(cli_test_gpx())),
    options,
    limits,
  ).unwrap()
  let item : PreparedOutput = { name: "a.gpx", redacted, }
  let path = root + "/staged.gpx"
  create_synced_file(path, redacted.bytes)
  assert_true(validate_staged(path, item, options, limits))
  @fs.write_file(path, b"PRIVATE_CORRUPTED_XML")
  assert_false(validate_staged(path, item, options, limits))
  let corrupted : PreparedOutput = {
    name: "bad.gpx",
    redacted: @model.make_redacted_file(
      b"PRIVATE_CORRUPTED_XML",
      redacted.preview,
    ),
  }
  match publish_outputs(root + "/exports", [item, corrupted], options, limits) {
    Ok(_) => fail("corrupted stage unexpectedly published")
    Err((count, diagnostic)) => {
      assert_eq(count, 0)
      assert_eq(diagnostic.code, "output.write_failed")
      assert_false(diagnostic.message.contains("PRIVATE_CORRUPTED_XML"))
    }
  }
  assert_false(@fs.exists(root + "/exports"))
  assert_false(@fs.exists(root + "/exports.trackshield-stage"))
}

///|
test "redact path and diagnostic helpers preserve component boundaries" {
  assert_true(path_contains("C:/Input", "c:/input/new"))
  assert_false(path_contains("C:/Input", "c:/input-other/new"))
  assert_eq(quoted_path("file\n\r\t\"\\"), "\"file\\n\\r\\t\\\"\\\\\"")
  for name in ["CON.gpx", "a.gpx.", "a:gpx", "a gpx", "../a.gpx", "é.gpx"] {
    assert_false(safe_output_name(name))
  }
}

///|
test "redact diagnostic paths escape Unicode line separators" {
  let path = StringBuilder()
  path.write_string("before")
  for codepoint in [0x85, 0x2028, 0x2029] {
    path.write_char(codepoint.unsafe_to_char())
  }
  path.write_string("after")
  assert_eq(quoted_path(path.to_string()), "\"before???after\"")
}

///|
async test "redact canonical aliases deduplicate and sibling prefixes do not overlap" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let source = root + "/inputs/a.gpx"
  let before = @fs.read_file(source).binary()
  let outcome = run_cli(
    redact_args(
      [source, root + "/inputs/./a.gpx", root + "/inputs"],
      output=root + "/inputs-other",
    ),
  )
  assert_eq(outcome.exit_code, 0)
  assert_true(outcome.stdout.contains("files=1 ready=1 failed=0 written=1"))
  assert_eq(@fs.read_file(source).binary(), before)
  assert_eq(@fs.read_file(root + "/inputs-other/a.gpx").binary(), before)
}

///|
async test "redact bounded reads enforce exact file and collection byte budgets" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/inputs/a.gpx"
  let bytes = @fs.read_file(path).binary()
  let size = bytes.length()
  let limits = @api.make_input_limits(size, 100, 2, size * 2, 128, 1000).unwrap()
  assert_eq(read_redaction_input(path, limits, size.to_int64()).unwrap(), bytes)
  match read_redaction_input(path, limits, (size + 1).to_int64()) {
    Ok(_) => fail("total byte limit bypassed")
    Err(diagnostic) => assert_eq(diagnostic.code, "input.total_bytes_exceeded")
  }
  let small = @api.make_input_limits(size - 1, 100, 2, size * 2, 128, 1000).unwrap()
  match read_redaction_input(path, small, 0) {
    Ok(_) => fail("file byte limit bypassed")
    Err(diagnostic) => assert_eq(diagnostic.code, @api.code_file_too_large)
  }
}

///|
test "redact parser maps every documented category and explicit negative center" {
  let labels = [
    "creator", "metadata_name", "metadata_description", "author_name", "author_email",
    "link", "track_name", "track_description", "route_name", "route_description",
    "waypoint_name", "waypoint_description", "point_timestamp", "extensions",
  ]
  for label in labels {
    let config = parse_redact_cli([
      "redact", "a.gpx", "--center", "-5,-6", "--radius-m", "100", "--remove-metadata",
      label,
    ]).unwrap()
    assert_eq(config.options.remove_metadata.length(), 1)
    assert_eq(config.options.remove_metadata[0].to_string(), label)
  }
}

///|
async test "redact staging cleanup owns only successfully created files" {
  let root = redact_fixture_root()
  defer @fs.rmdir(root, recursive=true)
  let existing = root + "/unexpected.gpx"
  @fs.write_file(existing, b"do not remove")
  let owned : Array[String] = []
  let rejected = try {
    create_staged_file(existing, b"replacement", owned)
    false
  } catch {
    _ => true
  } noraise {
    value => value
  }
  assert_true(rejected)
  assert_eq(owned, [])
  assert_eq(@fs.read_file(existing).binary(), b"do not remove")
  let created = root + "/owned.gpx"
  create_staged_file(created, b"created by us", owned)
  assert_eq(owned, [created])
  for path in owned {
    @fs.remove(path)
  }
  assert_eq(@fs.read_file(existing).binary(), b"do not remove")
}
