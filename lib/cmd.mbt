///|
pub fn println_cmd(cmd : String, args : Array[String]) -> Unit {
  let arr = [cmd]
  push_all(arr, args)
  println("执行命令：" + yellow(arr.join(" ")))
}

///|
pub async fn run(cmd : String, args : Array[String]) -> Bool {
  // println_cmd(cmd, args)
  @process.run(cmd, args) == 0
}

///|
pub async fn run_with_stdout_to_file(
  cmd : String,
  args : Array[String],
  output_file : String,
) -> Bool {
  let print_args = args.copy()
  print_args..push(">")..push(output_file)
  // println_cmd(cmd, args)
  let stdout = @process.redirect_to_file(output_file, create=0o644)
  @process.run(cmd, args, stdout~) == 0
}
