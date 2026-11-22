open Domain

(* The reader of the previous version of the format. It produces the domain
   type of this version directly: there is no second model of the claim. *)

(* The version this reader reads. *)
val previous_version : int

(* The specification of the previous version, read as the specification of
   this one. *)
val read_spec : string -> (spec, string) result

(* A record of the previous version, read as a record of this one. The tool
   that produced it cannot be known, so it is unknown. *)
val read_evidence : Yojson.Safe.t -> (evidence, string) result

(* The migrated records are bound to the definition of the migrated claim: the
   definition did not change with the format, only the fields the previous
   version hashed and this one does not read. The binding that really changed
   is the environment, and the migrated record keeps the environment of the
   previous version. *)
val rebind_definitions : spec -> evidence list -> evidence list

(* The tool a migrated record carries: the class is known, the fingerprint is
   not. *)
val unknown_tool : tool
