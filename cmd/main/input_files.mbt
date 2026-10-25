///|
enum BoundedReadError {
  LimitExceeded(Int32)
  IoFailure(Int32)
}

///|
/// Discover lowercase `.gpx` files in stable path order. Directory entries
/// marked as links are never traversed; a nested link is reported as a warning
/// so the caller can see that the audit intentionally skipped it.
async fn collect_gpx_paths(
  config : CliConfig,
) -> (Array[String], Array[@model.FileInspection]) {
  let paths : Array[String] = []
  let file_identity_keys : Array[String] = []
  let directory_identity_keys : Array[String] = []
  let inspections : Array[@model.FileInspection] = []
  let mut stopped = false
  for input_path in config.paths {
    if !stopped {
      stopped = collect_input_path(
        input_path, config, paths, file_identity_keys, directory_identity_keys, inspections,
        true,
      )
    }
  }
  paths.sort()
  (paths, inspections)
}

///|
/// Returns true when the max-files boundary has been reached and traversal
/// should stop. Sorting each directory before recursion makes the selected
/// prefix stable when a collection exceeds its configured limit.
async fn collect_input_path(
  path : String,
  config : CliConfig,
  paths : Array[String],
  file_identity_keys : Array[String],
  directory_identity_keys : Array[String],
  inspections : Array[@model.FileInspection],
  explicit : Bool,
) -> Bool {
  if path_has_link_component(path) {
    inspections.push(
      skipped_link(path, if explicit { @model.Error } else { @model.Warning }),
    )
    return false
  }
  let kind = try @fs.kind(path, follow_symlink=false) catch {
    _ => {
      inspections.push(
        input_problem(
          path, "input.path_unreadable", "input path could not be inspected",
        ),
      )
      return false
    }
  } noraise {
    value => value
  }
  match kind {
    @fs.SymLink => {
      inspections.push(
        skipped_link(path, if explicit { @model.Error } else { @model.Warning }),
      )
      false
    }
    @fs.Directory => {
      let directory_key = match canonical_path_key(path) {
        Some(value) => value
        None => {
          inspections.push(
            input_problem(
              path, "input.path_unreadable", "directory path could not be resolved",
            ),
          )
          return false
        }
      }
      if directory_identity_keys.contains(directory_key) {
        return false
      }
      directory_identity_keys.push(directory_key)
      let children = try @fs.readdir(path, sort=true) catch {
        _ => {
          inspections.push(
            input_problem(
              path, "input.path_unreadable", "directory entries could not be read",
            ),
          )
          return false
        }
      } noraise {
        value => value
      }
      let mut stop = false
      for child in children {
        if !stop {
          stop = collect_input_path(
            path + "/" + child,
            config,
            paths,
            file_identity_keys,
            directory_identity_keys,
            inspections,
            false,
          )
        }
      }
      stop
    }
    @fs.Regular =>
      if is_gpx_path(path) {
        let file_key = match canonical_path_key(path) {
          Some(value) => value
          None => {
            inspections.push(
              input_problem(
                path, "input.path_unreadable", "file path could not be resolved",
              ),
            )
            return false
          }
        }
        if file_identity_keys.contains(file_key) {
          false
        } else if paths.length() >= config.limits.max_files {
          inspections.push(
            input_problem(
              path, "input.file_limit_exceeded", "collection contains more GPX files than the configured limit",
            ),
          )
          true
        } else {
          paths.push(path)
          file_identity_keys.push(file_key)
          false
        }
      } else if explicit {
        inspections.push(
          input_problem(
            path, "cli.unsupported_extension", "explicit input file must use the .gpx extension",
          ),
        )
        false
      } else {
        false
      }
    _ => {
      if explicit {
        inspections.push(
          input_problem(
            path, "input.path_unreadable", "input is not a readable regular file or directory",
          ),
        )
      }
      false
    }
  }
}

///|
async fn canonical_path_key(path : String) -> String? {
  try @fs.realpath(path) catch {
    _ => return None
  } noraise {
    value => Some(value)
  }
}

///|
/// Check every existing prefix before any operation can follow an intermediate
/// reparse point. `kind(..., follow_symlink=false)` only inspects the final path
/// component, so each parent must be checked separately.
async fn path_has_link_component(path : String) -> Bool {
  let (normalized, components) = split_path_components(path)
  let absolute_path = if is_absolute_path(normalized, components) {
    normalized
  } else {
    match @env.current_dir() {
      Some(directory) => directory + "/" + normalized
      None => normalized
    }
  }
  let (normalized, components) = split_path_components(absolute_path)
  let mut prefix = ""
  let mut first_component = 0
  if normalized.has_prefix("//") && components.length() >= 2 {
    prefix = "//" + components[0] + "/" + components[1]
    first_component = 2
    if is_link_component(prefix) {
      return true
    }
  } else if normalized.has_prefix("/") {
    prefix = "/"
  } else if components.length() > 0 &&
    components[0].length() == 2 &&
    components[0].has_suffix(":") {
    prefix = components[0] + "/"
    first_component = 1
  }
  for index in first_component..<components.length() {
    if prefix == "" {
      prefix = components[index]
    } else if prefix.has_suffix("/") {
      prefix += components[index]
    } else {
      prefix += "/" + components[index]
    }
    if is_link_component(prefix) {
      return true
    }
  }
  false
}

///|
fn is_absolute_path(normalized : String, components : Array[String]) -> Bool {
  if normalized.has_prefix("/") {
    return true
  }
  match components.get(0) {
    Some(drive) if drive.length() == 2 && drive.has_suffix(":") =>
      normalized.has_prefix(drive + "/")
    _ => false
  }
}

///|
fn split_path_components(path : String) -> (String, Array[String]) {
  let normalized = StringBuilder(size_hint=path.length())
  let components : Array[String] = []
  let mut component = ""
  for character in path {
    if character == '\\' {
      normalized.write_char('/')
      if component != "" {
        components.push(component)
        component = ""
      }
    } else if character == '/' {
      normalized.write_char('/')
      if component != "" {
        components.push(component)
        component = ""
      }
    } else {
      normalized.write_char(character)
      component += character.to_string()
    }
  }
  if component != "" {
    components.push(component)
  }
  (normalized.to_string(), components)
}

///|
async fn is_link_component(path : String) -> Bool {
  let kind = try @fs.kind(path, follow_symlink=false) catch {
    _ => @fs.Unknown
  } noraise {
    value => value
  }
  match kind {
    @fs.SymLink => true
    _ => false
  }
}

///|
fn is_gpx_path(path : String) -> Bool {
  path.has_suffix(".gpx")
}

///|
async fn load_and_inspect(config : CliConfig) -> Array[@model.FileInspection] {
  let (paths, inspections) = collect_gpx_paths(config)
  let mut total_bytes : Int64 = 0
  for path in paths {
    let (inspection, used_bytes) = inspect_path_with_limits(
      path,
      config.limits,
      total_bytes,
    )
    total_bytes += used_bytes
    inspections.push(inspection)
  }
  inspections
}

///|
async fn inspect_path_with_limits(
  path : String,
  limits : @api.InputLimits,
  total_bytes_before : Int64,
) -> (@model.FileInspection, Int64) {
  let file_size = try @fs.file_size(path) catch {
    _ =>
      return (
        input_problem(
          path, "input.path_unreadable", "file size could not be read",
        ),
        0,
      )
  } noraise {
    value => value
  }
  if file_size > limits.max_file_bytes.to_int64() {
    return (
      input_problem(
        path, @api.code_file_too_large, "file exceeds the configured byte limit",
      ),
      0,
    )
  }
  let total_limit = limits.max_total_bytes.to_int64()
  let remaining = total_limit - total_bytes_before
  if file_size > remaining {
    return (
      input_problem(
        path, "input.total_bytes_exceeded", "file exceeds the remaining collection byte budget",
      ),
      0,
    )
  }
  let file = try @fs.open(path, mode=@fs.ReadOnly) catch {
    _ =>
      return (
        input_problem(
          path, "input.path_unreadable", "file could not be opened for reading",
        ),
        0,
      )
  } noraise {
    value => value
  }
  defer file.close()
  let read_limit = limits.max_file_bytes.min(remaining.to_int())
  match read_bounded_file(file, read_limit) {
    Err(LimitExceeded(bytes_read)) =>
      if read_limit == limits.max_file_bytes {
        (
          input_problem(
            path, @api.code_file_too_large, "file grew beyond the configured byte limit while being read",
          ),
          bytes_read.to_int64(),
        )
      } else {
        (
          input_problem(
            path, "input.total_bytes_exceeded", "file grew beyond the remaining collection byte budget",
          ),
          bytes_read.to_int64(),
        )
      }
    Err(IoFailure(bytes_read)) =>
      (
        input_problem(
          path, "input.path_unreadable", "file could not be read completely",
        ),
        bytes_read.to_int64(),
      )
    Ok(bytes) => {
      let inspection = @api.inspect_gpx(
        @model.GpxInput::new(path, bytes),
        limits,
      )
      (inspection, bytes.length().to_int64())
    }
  }
}

///|
/// Read at most `limit + 1` bytes, so a file that grows after its size check
/// cannot bypass the configured memory bound.
async fn read_bounded_file(
  file : @fs.File,
  limit : Int32,
) -> Result[Bytes, BoundedReadError] {
  let collected : Array[Byte] = []
  while collected.length() <= limit {
    let remaining = limit + 1 - collected.length()
    let chunk_or_end = try file.read_some(max_len=remaining) catch {
      _ => return Err(IoFailure(collected.length()))
    } noraise {
      value => value
    }
    match chunk_or_end {
      None => return Ok(Bytes::from_array(collected))
      Some(chunk) => {
        if chunk.length() == 0 {
          return Ok(Bytes::from_array(collected))
        }
        for byte in chunk {
          collected.push(byte)
        }
        if collected.length() > limit {
          return Err(LimitExceeded(collected.length()))
        }
      }
    }
  }
  Err(LimitExceeded(collected.length()))
}

///|
fn input_problem(
  path : String,
  code : String,
  message : String,
) -> @model.FileInspection {
  let diagnostic = @model.Diagnostic::new(code, @model.Error, path, message)
  @model.make_file_inspection(path, [], [], [diagnostic], 0, 0, false)
}

///|
fn skipped_link(
  path : String,
  severity : @model.Severity,
) -> @model.FileInspection {
  let diagnostic = @model.Diagnostic::new(
    "input.link_skipped", severity, path, "symbolic links and reparse points are not followed",
  )
  @model.make_file_inspection(path, [], [], [diagnostic], 0, 0, true)
}
