///|
async fn is_gzip_file(path : String) -> Bool {
  let f = @fs.open(path, mode=@fs.Mode::ReadOnly)
  defer f.close()
  // 文件至少要有 2 个字节
  if f.size() < 2 {
    f.close()
    return false
  }
  let b1 = f.read_exactly(1)
  let b2 = f.read_exactly(1)
  b1 == b"\x1f" && b2 == b"\x8b"
}

///|
pub fn renmae_file(from_path : String, to_path : String) -> Bool {
  let err = c_rename_file(
    @encoding/utf8.encode(from_path),
    @encoding/utf8.encode(to_path),
  )
  err == 0
}
