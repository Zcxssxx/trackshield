///|
enum ReportFormat {
  Text
  Json
} derive(Eq, Debug)

///|
struct CliConfig {
  paths : Array[String]
  radius_m : Double
  min_distinct_files : Int32
  format : ReportFormat
  show_coordinates : Bool
  limits : @api.InputLimits
}

///|
fn root_command() -> @argparse.Command {
  @argparse.Command(
    "trackshield",
    about="Audit GPX collections for repeated endpoint and metadata exposure",
    subcommands=[audit_command()],
    subcommand_required=true,
    disable_help_subcommand=true,
  )
}

///|
fn audit_command() -> @argparse.Command {
  @argparse.Command(
    "audit",
    about="Analyze GPX files and directories without modifying them",
    options=[
      @argparse.OptionArg(
        "radius-m",
        about="Endpoint grouping radius in metres (default: 500)",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "min-files",
        about="Distinct source files required for a clue (default: 3)",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg("format", about="Report format: text or json"),
      @argparse.OptionArg(
        "max-file-bytes",
        about="Maximum bytes read from one GPX file",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "max-points",
        about="Maximum parsed points per file",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "max-files",
        about="Maximum candidate GPX files analyzed",
        allow_hyphen_values=true,
      ),
      @argparse.OptionArg(
        "max-total-bytes",
        about="Maximum bytes accepted across the collection",
        allow_hyphen_values=true,
      ),
    ],
    flags=[
      @argparse.FlagArg(
        "show-coordinates",
        about="Include sensitive cluster centers in the report",
      ),
    ],
    positionals=[
      @argparse.PositionArg(
        "paths",
        about="One or more GPX files or directories",
        num_args=@argparse.ValueRange(lower=1),
      ),
    ],
    disable_help_subcommand=true,
  )
}

///|
/// Parse and validate CLI options without performing filesystem access.
fn parse_cli(argv : Array[String]) -> Result[CliConfig, String] {
  let matches = root_command().parse(argv~, env=Map([])) catch {
    _ => return Err("invalid command line for audit; run trackshield --help")
  }
  let audit_matches = match matches.subcommand {
    Some(("audit", parsed)) => parsed
    _ => return Err("expected the audit command")
  }
  let paths = match audit_matches.values.get("paths") {
    Some(values) if !values.is_empty() => values.copy()
    _ => return Err("provide at least one input path")
  }
  paths.sort()

  let defaults = @api.default_input_limits()
  let radius_text = value_or(audit_matches.values, "radius-m", "500")
  let radius_m : Double = @string.from_str(radius_text) catch {
    _ => return Err("--radius-m must be a finite positive number")
  }
  let min_files = match audit_matches.values.get("min-files") {
    Some([value, ..]) =>
      match parse_positive_int(value) {
        Ok(parsed) => parsed
        Err(message) => return Err("--min-files " + message)
      }
    _ => 3
  }
  let format = match value_or(audit_matches.values, "format", "text") {
    "text" => Text
    "json" => Json
    _ => return Err("--format must be text or json")
  }
  let max_file_bytes = match
    parse_optional_limit(
      audit_matches.values,
      "max-file-bytes",
      defaults.max_file_bytes,
    ) {
    Ok(value) => value
    Err(message) => return Err("--max-file-bytes " + message)
  }
  let max_points = match
    parse_optional_limit(
      audit_matches.values,
      "max-points",
      defaults.max_points_per_file,
    ) {
    Ok(value) => value
    Err(message) => return Err("--max-points " + message)
  }
  let max_files = match
    parse_optional_limit(audit_matches.values, "max-files", defaults.max_files) {
    Ok(value) => value
    Err(message) => return Err("--max-files " + message)
  }
  let max_total_bytes = match
    parse_optional_limit(
      audit_matches.values,
      "max-total-bytes",
      defaults.max_total_bytes,
    ) {
    Ok(value) => value
    Err(message) => return Err("--max-total-bytes " + message)
  }
  let limits = match
    @api.make_input_limits(
      max_file_bytes,
      max_points,
      max_files,
      max_total_bytes,
      defaults.max_xml_depth,
      defaults.max_xml_elements.max(max_points),
    ) {
    Ok(value) => value
    Err(_) => return Err("resource limits are outside supported bounds")
  }
  let show_coordinates = match audit_matches.flags.get("show-coordinates") {
    Some(value) => value
    None => false
  }
  match @api.make_audit_options(radius_m, min_files, show_coordinates) {
    Ok(options) =>
      Ok({
        paths,
        radius_m: options.radius_m,
        min_distinct_files: options.min_distinct_files,
        format,
        show_coordinates,
        limits,
      })
    Err(_) => Err("--radius-m or --min-files is outside supported bounds")
  }
}

///|
fn value_or(
  values : Map[String, Array[String]],
  key : String,
  fallback : String,
) -> String {
  match values.get(key) {
    Some([value, ..]) => value
    _ => fallback
  }
}

///|
fn parse_optional_limit(
  values : Map[String, Array[String]],
  key : String,
  fallback : Int32,
) -> Result[Int32, String] {
  match values.get(key) {
    Some([value, ..]) => parse_positive_int(value)
    _ => Ok(fallback)
  }
}

///|
fn parse_positive_int(value : String) -> Result[Int32, String] {
  let parsed : Int32 = @string.from_str(value) catch {
    _ => return Err("must be a positive integer")
  }
  if parsed <= 0 {
    Err("must be a positive integer")
  } else {
    Ok(parsed)
  }
}

///|
fn cli_help(argv : Array[String]) -> String? {
  if argv.any(value => value == "--help" || value == "-h") {
    if argv.length() > 0 && argv[0] == "audit" {
      Some(audit_command().render_help())
    } else {
      Some(root_command().render_help())
    }
  } else {
    None
  }
}

///|
/// `@env.args()` includes the native executable prefix; `Command.parse(argv=)`
/// expects user arguments only.
fn cli_arguments(runtime_args : Array[String]) -> Array[String] {
  if runtime_args.is_empty() {
    []
  } else {
    runtime_args[1:].to_owned()
  }
}
