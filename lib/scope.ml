type target =
  | PathTarget of string
  | CapabilityTarget of string
  | InterfaceTarget of string

type t = target list

let covers _t _path = false
