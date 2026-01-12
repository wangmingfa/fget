///|
async fn gzip_cleanup(
  src_file_path : String,
  output_file_path : String,
  retain_src_file? : Bool = true,
  success : Bool,
) -> Unit {
  if success {
    if !retain_src_file {
      // 删除源文件
      @fs.remove(src_file_path)
    }
  } else if @fs.exists(output_file_path) {
    // 失败了，删除目标文件
    @fs.remove(output_file_path)
  }
}

///|
pub fn gzip_decode(input : Bytes) -> Bytes raise Failure {
  let decoder = gzip_decoder_new()
  let userdata = @buffer.new()
  let res = gzip_decoder_push(
    decoder,
    input,
    input.length(),
    fn(userdata, data, len) {
      let data = data[0:len.to_int()].to_bytes()
      userdata.write_bytes(data)
    },
    userdata,
  )
  gzip_decoder_free(decoder)
  if res == 0 {
    return userdata.to_bytes()
  }
  raise fail("gzip失败")
}

///|
pub async fn gzip_decode_file(input_file_path : String) -> Bytes raise Failure {
  let data = @fs.read_file(input_file_path) catch {
    e => {
      println("错误信息：\{e}")
      raise fail("读取文件失败")
    }
  }
  let output = gzip_decode(data.binary()) catch {
    e => raise fail("gzip解码失败: \{e}")
  }
  output
}

///|
async test "test_gzip_decode_file" {
  let file_path = generate_gzip_file()
  let output = @encoding/utf8.decode_lossy(gzip_decode_file(file_path))
  @fs.remove(file_path)
  let (_, data) = @http.get(TEST_URL)
  inspect(output, content=data.text())
}

///|
pub async fn gzip_decode_file_to_target(
  input_file_path : String,
  output_file_path : String,
  retain_src_file? : Bool = true,
) -> Unit raise Failure {
  let output = gzip_decode_file(input_file_path) catch { e => raise e }
  @fs.write_file(output_file_path, output, create=0o640) catch {
    e => {
      println("原因：\{e}")
      raise fail("写入到文件失败: \{output_file_path}")
    }
  }
  gzip_cleanup(input_file_path, output_file_path, retain_src_file~, true) catch {
    _ => println("清理失败")
  }
  let is_gzip = is_gzip_file(output_file_path) catch { _ => raise fail("") }
  if is_gzip {
    raise fail("gzip解码失败")
  }
}

///|
async test "test_gzip_decode_file_to_target" {
  let file_path = generate_gzip_file()
  guard @env.current_dir() is Some(dir) else { panic() }
  let output_file = "\{dir}/output.html"
  gzip_decode_file_to_target(file_path, output_file)
  @fs.remove(file_path)
  let result = @fs.read_file(output_file).text()
  @fs.remove(output_file)
  let (_, data) = @http.get(TEST_URL)
  inspect(result, content=data.text())
}

///|
const TEST_URL = "https://meat.vivo.xyz"

///|
async fn generate_gzip_file() -> String {
  let dir = @env.current_dir().unwrap_or_error(
    StringError("无法获取当前目录"),
  )
  // 下载一个gzip文件
  let file_path = dir + "/page.gz"
  let success = run("wget", [
    "--header=Accept-Encoding: gzip",
    "--compression=none",
    "-O",
    file_path,
    TEST_URL,
  ])
  if !success {
    raise fail("无法下载gzip文件")
  }
  // 判断是否为gzip文件
  if !is_gzip_file(file_path) {
    println("文件" + red(file_path) + "不是gzip文件")
    raise fail("失败")
  }
  file_path
}

///|
async test "test_generate_gzip_file" {
  let gzip_file_path = generate_gzip_file()
  let actual = @fs.read_file(gzip_file_path)
  let (_, data) = @http.get(TEST_URL, headers={
    "User-Agent": "Mozilla/5.0",
    "Accept": "*/*",
    "Accept-Encoding": "gzip",
    "Connection": "keep-alive",
  })
  let expect = data.binary()
  assert_eq(actual.binary(), expect)
}
