///|
struct PreparedOutput {
  name : String
  redacted : @model.RedactedFile
}

///|
fn output_diagnostic(
  code : String,
  path : String,
  message : String,
) -> @model.Diagnostic {
  @model.Diagnostic::new(code, @model.Error, path, message)
}

///|
/// Conservative portable leaf names avoid Windows devices, alternate streams,
/// trailing-dot aliases, and Unicode case-folding ambiguities in the flat map.
fn safe_output_name(name : String) -> Bool {
  if name == "" ||
    name == "." ||
    name == ".." ||
    name.has_suffix(".") ||
    name.length() > 180 {
    return false
  }
  for ch in name {
    if !(ch >= 'a' && ch <= 'z') &&
      !(ch >= 'A' && ch <= 'Z') &&
      !(ch >= '0' && ch <= '9') &&
      ch != '.' &&
      ch != '_' &&
      ch != '-' {
      return false
    }
  }
  let stem = name.split(".").next().unwrap().to_owned()
  let stem = path_key(stem)
  ![
    "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7",
    "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8",
    "lpt9",
  ].contains(stem)
}

///|
/// Accept local ordinary paths only. Device/UNC/drive-relative paths and
/// ambiguous Windows spellings are rejected before filesystem discovery.
fn ordinary_path_syntax(path : String) -> Bool {
  let (normalized, components) = split_path_components(path)
  if path == "" || normalized.has_prefix("//") {
    return false
  }
  for ch in path {
    if ch.to_int() < 32 ||
      ch.to_int() == 127 ||
      ch == '<' ||
      ch == '>' ||
      ch == '"' ||
      ch == '|' ||
      ch == '?' ||
      ch == '*' {
      return false
    }
  }
  for i, component in components {
    if i == 0 && component.length() == 2 && component.has_suffix(":") {
      if !normalized.has_prefix(component + "/") {
        return false
      }
      let drive = component[0]
      if !(drive >= 'a' && drive <= 'z') && !(drive >= 'A' && drive <= 'Z') {
        return false
      }
    } else if component.contains(":") ||
      component.has_suffix(" ") ||
      (component != "." && component != ".." && component.has_suffix(".")) {
      return false
    } else {
      let stem = path_key(component.split(".").next().unwrap().to_owned())
      if [
          "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6",
          "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6",
          "lpt7", "lpt8", "lpt9",
        ].contains(stem) {
        return false
      }
    }
  }
  true
}

///|
fn path_key(path : String) -> String {
  let result = StringBuilder()
  for ch in path {
    if ch == '\\' {
      result.write_char('/')
    } else if ch >= 'A' && ch <= 'Z' {
      result.write_char((ch.to_int() + 32).unsafe_to_char())
    } else {
      result.write_char(ch)
    }
  }
  result.to_string()
}

///|
async fn resolved_local_path(path : String) -> String {
  let (normalized, _) = split_path_components(@fs.realpath(path))
  // realpath uses GetFinalPathNameByHandleW on Windows; turn the local DOS
  // extended spelling back into an ordinary absolute path for slash joining.
  if normalized.has_prefix("//?/") {
    normalized[4:].to_owned()
  } else {
    normalized
  }
}

///|
fn path_contains(parent : String, child : String) -> Bool {
  let parent = path_key(parent).trim_end(chars="/").to_owned()
  let child = path_key(child).trim_end(chars="/").to_owned()
  child == parent || child.has_prefix(parent + "/")
}

///|
async fn preflight_destination(
  output : String,
  roots : Array[String],
  files : Array[String],
) -> Result[String, @model.Diagnostic] {
  let problem = fn(code, message) { output_diagnostic(code, output, message) }
  if !ordinary_path_syntax(output) {
    return Err(
      problem("output.unsafe_path", "destination path syntax is unsupported"),
    )
  }
  let (normalized, components) = split_path_components(output)
  if normalized.has_suffix("/") ||
    components.is_empty() ||
    !safe_output_name(components[components.length() - 1]) {
    return Err(
      problem(
        "output.unsafe_path", "destination must have a portable new directory name",
      ),
    )
  }
  if path_has_link_component(output) {
    return Err(
      problem(
        "output.link_rejected", "destination traverses a symbolic link or reparse point",
      ),
    )
  }
  let present = try @fs.exists(output) catch {
    _ =>
      return Err(
        problem("output.path_unreadable", "destination could not be inspected"),
      )
  } noraise {
    value => value
  }
  if present {
    return Err(problem("output.exists", "destination already exists"))
  }
  let parent = match normalized.rev_find("/") {
    Some(0) => "/"
    Some(index) => normalized[:index].to_owned() + "/"
    None => "."
  }
  let parent_kind = try @fs.kind(parent, follow_symlink=false) catch {
    _ =>
      return Err(
        problem(
          "output.parent_unavailable", "destination parent must already exist",
        ),
      )
  } noraise {
    value => value
  }
  if parent_kind != @fs.Directory || path_has_link_component(parent) {
    return Err(
      problem(
        "output.parent_unavailable", "destination parent must be an ordinary directory",
      ),
    )
  }
  let canonical_parent = try resolved_local_path(parent) catch {
    _ =>
      return Err(
        problem(
          "output.parent_unavailable", "destination parent could not be resolved",
        ),
      )
  } noraise {
    value => value
  }
  let destination = canonical_parent.trim_end(chars="/").to_owned() +
    "/" +
    components[components.length() - 1]
  for root in roots {
    let canonical_root = try resolved_local_path(root) catch {
      _ =>
        return Err(
          problem(
            "output.input_unavailable", "input root could not be resolved",
          ),
        )
    } noraise {
      value => value
    }
    let kind = try @fs.kind(root, follow_symlink=false) catch {
      _ =>
        return Err(
          problem(
            "output.input_unavailable", "input root could not be inspected",
          ),
        )
    } noraise {
      value => value
    }
    if path_contains(destination, canonical_root) ||
      (kind == @fs.Directory && path_contains(canonical_root, destination)) {
      return Err(
        problem("output.input_overlap", "destination overlaps an input root"),
      )
    }
  }
  for file in files {
    let canonical_file = try resolved_local_path(file) catch {
      _ =>
        return Err(
          problem(
            "output.input_unavailable", "input file could not be resolved",
          ),
        )
    } noraise {
      value => value
    }
    if path_contains(destination, canonical_file) {
      return Err(
        problem("output.input_overlap", "destination overlaps an input file"),
      )
    }
  }
  Ok(destination)
}

///|
async fn read_redaction_input(
  path : String,
  limits : @api.InputLimits,
  used : Int64,
) -> Result[Bytes, @model.Diagnostic] {
  let fail_read = fn(code, message) { output_diagnostic(code, path, message) }
  if path_has_link_component(path) {
    return Err(
      fail_read(
        "input.link_skipped", "symbolic links and reparse points are not followed",
      ),
    )
  }
  let file = try @fs.open(path, mode=@fs.ReadOnly) catch {
    _ =>
      return Err(
        fail_read("input.path_unreadable", "input could not be opened"),
      )
  } noraise {
    value => value
  }
  defer file.close()
  if file.kind() != @fs.Regular {
    return Err(
      fail_read("input.path_unreadable", "input must be a regular file"),
    )
  }
  let remaining = limits.max_total_bytes.to_int64() - used
  let read_limit = limits.max_file_bytes.min(remaining.max(0).to_int())
  match read_bounded_file(file, read_limit) {
    Ok(bytes) => Ok(bytes)
    Err(LimitExceeded(_)) =>
      Err(
        fail_read(
          if read_limit < limits.max_file_bytes {
            "input.total_bytes_exceeded"
          } else {
            @api.code_file_too_large
          },
          "input exceeds the bounded byte budget",
        ),
      )
    Err(IoFailure(_)) =>
      Err(
        fail_read("input.path_unreadable", "input could not be read completely"),
      )
  }
}

///|
async fn create_synced_file(path : String, bytes : Bytes) -> Unit {
  let file = @fs.create(path, allow_existing=false, permission=0o600)
  defer file.close()
  file.write(bytes)
  file.sync()
}

///|
async fn create_staged_file(
  path : String,
  bytes : Bytes,
  owned_paths : Array[String],
) -> Unit {
  let file = @fs.create(path, allow_existing=false, permission=0o600)
  defer file.close()
  // Only a successful CREATE_NEW establishes cleanup ownership. Register
  // before write/sync so a partially written file still belongs to this run.
  owned_paths.push(path)
  file.write(bytes)
  file.sync()
}

///|
async fn validate_staged(
  path : String,
  item : PreparedOutput,
  options : @model.RedactionOptions,
  limits : @api.InputLimits,
) -> Bool {
  let bytes = match read_redaction_input(path, limits, 0) {
    Ok(bytes) => bytes
    Err(_) => return false
  }
  if bytes != item.redacted.bytes {
    return false
  }
  let input = @model.GpxInput::new(path, bytes)
  let inspection = @api.inspect_gpx(input, limits)
  if has_errors(inspection.diagnostics) {
    return false
  }
  let preview = @api.preview_redaction(input, options, limits)
  preview.points_removed == 0 &&
  !preview.output_would_be_empty &&
  preview.metadata_fields_removed ==
  (if options.remove_metadata.any(category => category is @model.Creator) {
    1
  } else {
    0
  })
}

///|
/// Path-based APIs cannot prevent concurrent parent replacement. Call only in
/// a trusted, stable directory tree. Never delete the final destination on a
/// failure: exclusive writes may have left a partial sensitive batch there.
async fn publish_outputs(
  destination : String,
  items : Array[PreparedOutput],
  options : @model.RedactionOptions,
  limits : @api.InputLimits,
) -> Result[Int32, (Int32, @model.Diagnostic)] {
  let stage = destination + ".trackshield-stage"
  let mut created_stage = false
  let mut written = 0
  let mut destination_created = false
  let staged_names : Array[String] = []
  let result = try {
    if path_has_link_component(destination) ||
      path_has_link_component(stage) ||
      @fs.exists(destination) {
      raise Failure("preflight changed")
    }
    @fs.mkdir(stage, permission=0o700)
    created_stage = true
    for item in items {
      let path = stage + "/" + item.name
      create_staged_file(path, item.redacted.bytes, staged_names)
    }
    for item in items {
      if !validate_staged(stage + "/" + item.name, item, options, limits) {
        raise Failure("staged output invalid")
      }
    }
    if path_has_link_component(destination) || path_has_link_component(stage) {
      raise Failure("preflight changed")
    }
    // async-fs Windows rename has an older-system COPY_ALLOWED fallback;
    // select the documented exclusive per-file publication strategy instead.
    @fs.mkdir(destination, permission=0o700)
    destination_created = true
    for item in items {
      let path = destination + "/" + item.name
      if path_has_link_component(destination) {
        raise Failure("preflight changed")
      }
      create_synced_file(path, item.redacted.bytes)
      if !validate_staged(path, item, options, limits) {
        raise Failure("published output invalid")
      }
      written += 1
    }
    Ok(written)
  } catch {
    _ =>
      Err(
        (
          written,
          output_diagnostic(
            if destination_created {
              "output.partial_write"
            } else {
              "output.write_failed"
            },
            destination,
            if destination_created {
              "publication failed; written counts only revalidated files; destination may also contain an unvalidated partial sensitive file; inspect and remove manually before retrying"
            } else {
              "staging or destination creation failed; no output batch was published"
            },
          ),
        ),
      )
  } noraise {
    value => value
  }
  let mut cleanup_failed = false
  if created_stage {
    for path in staged_names {
      @fs.remove(path) catch {
        _ => cleanup_failed = true
      }
    }
    @fs.rmdir(stage) catch {
      _ => cleanup_failed = true
    }
  }
  if cleanup_failed {
    Err(
      (
        written,
        output_diagnostic(
          "output.staging_cleanup_failed", stage, "sensitive staging files may remain; inspect and remove manually",
        ),
      ),
    )
  } else {
    result
  }
}

///|
/// Render filenames without allowing control characters to forge report lines.
fn quoted_path(path : String) -> String {
  let output = StringBuilder()
  output.write_char('"')
  for ch in path {
    match ch {
      '"' => output.write_string("\\\"")
      '\\' => output.write_string("\\\\")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      _ =>
        if ch.to_int() < 32 ||
          ch.to_int() == 127 ||
          ch.to_int() == 0x85 ||
          ch.to_int() == 0x2028 ||
          ch.to_int() == 0x2029 {
          output.write_char('?')
        } else {
          output.write_char(ch)
        }
    }
  }
  output.write_char('"')
  output.to_string()
}
