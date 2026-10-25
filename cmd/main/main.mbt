///|
/// Native process exit used only after both output streams have been flushed.
extern "C" fn exit_process(code : Int32) = "exit"

///|
async fn main {
  let outcome = run_cli(cli_arguments(@env.args()))
  if outcome.stdout != "" {
    @stdio.stdout.write(outcome.stdout)
  }
  if outcome.stderr != "" {
    @stdio.stderr.write(outcome.stderr)
  }
  if outcome.exit_code != 0 {
    exit_process(outcome.exit_code)
  }
}
