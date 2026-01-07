///|
#cfg(platform="windows")
pub async fn gzip_decode(
  src_file_path : String,
  out_file_path : String,
  retain_src_file? : Bool = true,
) -> Bool {
  // Windows: tar -xzf in.gz -O > out
  let success = run("tar", ["-xzf", src_file_path, "-O", ">", out_file_path])
  gzip_cleanup(src_file_path, out_file_path, retain_src_file, success)
  success
}

///|
#cfg(not(platform="windows"))
pub async fn gzip_decode(
  src_file_path : String,
  out_file_path : String,
  retain_src_file? : Bool = true,
) -> Bool {
  // macOS / Linux
  // gzip -dc in.gz > out
  let success = run_with_stdout_to_file(
    "gzip",
    ["-dc", src_file_path],
    out_file_path,
  )
  gzip_cleanup(src_file_path, out_file_path, retain_src_file, success)
  success
}

///|
async fn gzip_cleanup(
  src_file_path : String,
  out_file_path : String,
  retain_src_file : Bool,
  success : Bool,
) -> Unit {
  if success {
    if !retain_src_file {
      // 删除源文件
      @fs.remove(src_file_path)
    }
  } else if @fs.exists(out_file_path) {
    // 失败了，删除目标文件
    @fs.remove(out_file_path)
  }
}

///|
async test "test_gzip_decode" {
  let dir = @env.current_dir().unwrap_or_error(
    StringError("无法获取当前目录"),
  )
  // 下载一个gzip文件
  let file_path = dir + "/page"
  let success = run("wget", [
    "--header=Accept-Encoding: gzip", "--compression=none", "-O", file_path, "https://meat.vivo.xyz",
  ])
  if !success {
    raise fail("无法下载gzip文件")
  }
  // 判断是否为gzip文件
  if !is_gzip_file(file_path) {
    println("文件" + red(file_path) + "不是gzip文件")
    raise fail("失败")
  }
  let output_file_path = file_path + ".html"
  let success = gzip_decode(file_path, output_file_path, retain_src_file=true)
  if success {
    // 删除文件
    @fs.remove(file_path)
    @fs.remove(output_file_path)
  }
  assert_true(success)
}
