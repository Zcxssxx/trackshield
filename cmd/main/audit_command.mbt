///|
struct CliOutcome {
  stdout : String
  stderr : String
  exit_code : Int32
}

///|
/// Run the CLI as a testable boundary around parsing, filesystem loading,
/// analysis, formatting, and process status selection.
async fn run_cli(argv : Array[String]) -> CliOutcome {
  match cli_help(argv) {
    Some(help) => return { stdout: help, stderr: "", exit_code: 0, }
    None => ()
  }
  if argv.get(0) == Some("redact") {
    return run_redact_cli(argv)
  }
  let config = match parse_cli(argv) {
    Ok(config) => config
    Err(message) =>
      return {
        stdout: "",
        stderr: "trackshield: " + message + "\n",
        exit_code: 2,
      }
  }
  let options = @api.make_audit_options(
    config.radius_m,
    config.min_distinct_files,
    config.show_coordinates,
  ).unwrap()
  let inspections = load_and_inspect(config)
  let report = @api.audit_collection(inspections, options)
  let stdout = match config.format {
    Text => @api.render_text(report)
    Json => @api.render_json(report) + "\n"
  }
  let stderr = diagnostic_summary(report.diagnostics)
  {
    stdout,
    stderr,
    exit_code: if has_errors(report.diagnostics) {
      1
    } else {
      0
    },
  }
}

///|
fn has_errors(diagnostics : Array[@api.Diagnostic]) -> Bool {
  diagnostics.any(diagnostic => {
    match diagnostic.severity {
      @model.Error => true
      _ => false
    }
  })
}

///|
fn diagnostic_summary(diagnostics : Array[@api.Diagnostic]) -> String {
  let output = StringBuilder(size_hint=128)
  let sorted = diagnostics.copy()
  sorted.sort_by((left, right) => {
    let path_order = left.path.compare(right.path)
    if path_order != 0 {
      path_order
    } else {
      left.code.compare(right.code)
    }
  })
  for diagnostic in sorted {
    output.write_string(diagnostic.severity.to_string())
    output.write_char(' ')
    output.write_string(diagnostic.code)
    if diagnostic.path != "" {
      output.write_string(" [")
      output.write_string(diagnostic.path)
      output.write_char(']')
    }
    output.write_string(": ")
    output.write_string(diagnostic.message)
    output.write_char('\n')
  }
  output.to_string()
}
