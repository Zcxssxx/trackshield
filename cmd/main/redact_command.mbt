///|
struct RedactConfig {
  paths : Array[String]
  options : @model.RedactionOptions
  write : Bool
  output_dir : String?
}

///|
fn redact_command() -> @argparse.Command {
  @argparse.Command(
    "redact",
    about="Preview an explicit redaction circle; --write creates cleaned copies",
    options=[
      @argparse.OptionArg(
        "center",
        about="Required explicit LAT,LON",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "radius-m",
        about="Required positive radius in metres",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "remove-metadata",
        about="Comma-separated metadata category labels",
      ),
      @argparse.OptionArg(
        "output-dir",
        about="New output directory (required with --write)",
      ),
    ],
    flags=[
      @argparse.FlagArg(
        "write",
        about="Explicitly confirm writing new cleaned files",
      ),
    ],
    positionals=[
      @argparse.PositionArg("paths", num_args=@argparse.ValueRange(lower=1)),
    ],
    disable_help_subcommand=true,
  )
}

///|
fn parse_redact_cli(argv : Array[String]) -> Result[RedactConfig, String] {
  let matches = root_command().parse(argv~, env=Map([])) catch {
    _ =>
      return Err("invalid redact command line; run trackshield redact --help")
  }
  let parsed = match matches.subcommand {
    Some(("redact", parsed)) => parsed
    _ => return Err("expected redact")
  }
  let paths = match parsed.values.get("paths") {
    Some(values) if !values.is_empty() => values.copy()
    _ => return Err("provide at least one input path")
  }
  paths.sort()
  let center_text = value_or(parsed.values, "center", "")
  let pair = center_text.split(",").map(value => value.to_owned()).collect()
  if pair.length() != 2 {
    return Err("--center requires a valid LAT,LON pair")
  }
  let latitude : Double = @string.from_str(pair[0]) catch {
    _ => return Err("--center requires a valid LAT,LON pair")
  }
  let longitude : Double = @string.from_str(pair[1]) catch {
    _ => return Err("--center requires a valid LAT,LON pair")
  }
  let center = match @api.make_geo_point(latitude, longitude) {
    Ok(value) => value
    Err(_) =>
      return Err("--center requires finite coordinates in supported ranges")
  }
  let radius : Double = @string.from_str(
    value_or(parsed.values, "radius-m", ""),
  ) catch {
    _ => return Err("--radius-m requires a finite positive radius")
  }
  let categories : Array[@model.MetadataCategory] = []
  if parsed.values.contains("remove-metadata") {
    for label in value_or(parsed.values, "remove-metadata", "").split(",") {
      let category = match label {
        "creator" => @model.Creator
        "metadata_name" => @model.MetadataName
        "metadata_description" => @model.MetadataDescription
        "author_name" => @model.AuthorName
        "author_email" => @model.AuthorEmail
        "link" => @model.Link
        "track_name" => @model.TrackName
        "track_description" => @model.TrackDescription
        "route_name" => @model.RouteName
        "route_description" => @model.RouteDescription
        "waypoint_name" => @model.WaypointName
        "waypoint_description" => @model.WaypointDescription
        "point_timestamp" => @model.PointTimestamp
        "extensions" => @model.Extensions
        _ =>
          return Err("--remove-metadata contains an unknown or empty category")
      }
      categories.push(category)
    }
  }
  let options = match @api.make_redaction_options(center, radius, categories) {
    Ok(value) => value
    Err(_) => return Err("--radius-m is outside supported bounds")
  }
  let write = parsed.flags.get("write") == Some(true)
  let output_dir = match parsed.values.get("output-dir") {
    Some([value, ..]) if value != "" => Some(value)
    _ => None
  }
  if write && output_dir is None {
    return Err("--write requires --output-dir")
  }
  Ok({ paths, options, write, output_dir, })
}

///|
async fn run_redact_cli(argv : Array[String]) -> CliOutcome {
  let config = match parse_redact_cli(argv) {
    Ok(value) => value
    Err(message) =>
      return {
        stdout: "",
        stderr: "trackshield: " + message + "\n",
        exit_code: 2,
      }
  }
  let limits = @api.default_input_limits()
  let diagnostics : Array[@model.Diagnostic] = []
  // The same deterministic, bounded discovery used by audit.
  let discovery : CliConfig = {
    paths: config.paths,
    radius_m: config.options.radius_m,
    min_distinct_files: 3,
    format: Text,
    show_coordinates: false,
    limits,
  }
  for path in config.paths {
    if !ordinary_path_syntax(path) {
      diagnostics.push(
        output_diagnostic(
          "input.unsafe_path", path, "input path syntax is unsupported",
        ),
      )
    }
  }
  if !diagnostics.is_empty() {
    return redaction_outcome(config.write, 0, [], 0, diagnostics)
  }
  let (paths, inspections) = collect_gpx_paths(discovery)
  for inspection in inspections {
    for diagnostic in inspection.diagnostics {
      // Audit can report a partial collection after skipping a nested link.
      // Redaction must refuse that incomplete batch, even if it has no files.
      diagnostics.push(
        output_diagnostic(diagnostic.code, diagnostic.path, diagnostic.message),
      )
    }
  }
  // Flatten to conservative portable basenames, resolving every collision
  // before reading transformations or creating a staging directory.
  let names : Array[String] = []
  let name_keys : Array[String] = []
  for path in paths {
    let (_, components) = split_path_components(path)
    let name = components[components.length() - 1]
    if !safe_output_name(name) {
      diagnostics.push(
        output_diagnostic(
          "output.unsafe_basename", path, "output basenames must use portable ASCII letters, digits, dots, underscores or hyphens",
        ),
      )
    } else if name_keys.contains(path_key(name)) {
      diagnostics.push(
        output_diagnostic(
          "output.basename_collision", path, "multiple inputs derive the same case-insensitive destination basename",
        ),
      )
    }
    names.push(name)
    name_keys.push(path_key(name))
  }
  let destination = if config.write {
    match
      preflight_destination(config.output_dir.unwrap(), config.paths, paths) {
      Ok(value) => Some(value)
      Err(diagnostic) => {
        diagnostics.push(diagnostic)
        None
      }
    }
  } else {
    None
  }
  if !diagnostics.is_empty() {
    return redaction_outcome(config.write, paths.length(), [], 0, diagnostics)
  }
  let prepared : Array[PreparedOutput] = []
  let mut used : Int64 = 0
  for index, path in paths {
    match read_redaction_input(path, limits, used) {
      Err(diagnostic) => diagnostics.push(diagnostic)
      Ok(bytes) => {
        used += bytes.length().to_int64()
        match
          @api.redact_gpx(
            @model.GpxInput::new(path, bytes),
            config.options,
            limits,
          ) {
          Err(diagnostic) => diagnostics.push(diagnostic)
          Ok(redacted) => {
            diagnostics.append(redacted.preview.diagnostics)
            prepared.push({ name: names[index], redacted, })
          }
        }
      }
    }
  }
  let mut written = 0
  // Failed transformations (including warnings such as empty_result) never
  // yield prepared items. Informational successful-preview diagnostics are OK.
  if config.write &&
    prepared.length() == paths.length() &&
    !has_errors(diagnostics) {
    match
      publish_outputs(destination.unwrap(), prepared, config.options, limits) {
      Ok(count) => written = count
      Err((count, diagnostic)) => {
        written = count
        diagnostics.push(diagnostic)
      }
    }
  }
  let outcome = redaction_outcome(
    config.write,
    paths.length(),
    prepared,
    written,
    diagnostics,
  )
  let published = StringBuilder()
  if destination is Some(directory) {
    for index in 0..<written {
      published.write_string(
        "output=" + quoted_path(directory + "/" + prepared[index].name) + "\n",
      )
    }
  }
  {
    stdout: outcome.stdout + published.to_string(),
    stderr: outcome.stderr,
    exit_code: outcome.exit_code,
  }
}

///|
fn redaction_outcome(
  write : Bool,
  files : Int32,
  prepared : Array[PreparedOutput],
  written : Int32,
  diagnostics : Array[@model.Diagnostic],
) -> CliOutcome {
  let output = StringBuilder()
  let failed = (files - prepared.length()).max(0)
  output.write_string(if write { "Write: " } else { "Preview: " })
  output.write_string(
    "files=\{files} ready=\{prepared.length()} failed=\{failed} written=\{written}\n",
  )
  for item in prepared {
    let preview = item.redacted.preview
    output.write_string("source=" + quoted_path(preview.source_path))
    output.write_string(
      " points_removed=\{preview.points_removed} segments_created=\{preview.segments_created} routes_removed=\{preview.routes_removed} waypoints_removed=\{preview.waypoints_removed} metadata_fields_removed=\{preview.metadata_fields_removed}\n",
    )
    if !write {
      output.write_string(
        "would_write_basename=" + quoted_path(item.name) + "\n",
      )
    }
  }
  output.write_string("Cleaned files and reports remain sensitive.\n")
  let errors = StringBuilder()
  let ordered = diagnostics.copy()
  ordered.sort_by((a, b) => {
    let c = a.path.compare(b.path)
    if c == 0 {
      a.code.compare(b.code)
    } else {
      c
    }
  })
  for diagnostic in ordered {
    errors.write_string(
      diagnostic.severity.to_string() +
      " " +
      diagnostic.code +
      " " +
      quoted_path(diagnostic.path) +
      ": " +
      diagnostic.message +
      "\n",
    )
  }
  {
    stdout: output.to_string(),
    stderr: errors.to_string(),
    exit_code: if failed > 0 ||
      has_errors(diagnostics) ||
      (write && written != files) {
      2
    } else {
      0
    },
  }
}
