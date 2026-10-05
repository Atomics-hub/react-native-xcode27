public func interopError() -> Bool {
  let error = interop.makeError(std.string("boom"))
  return error.__convertToBool()
}
