import { ERROR_KEYS, readCodedError } from "../../shared/errors";
import type { Translate } from "./translate";

/**
 * The text of a failure the human is meant to read.
 *
 * A failure that travels as a code is read in the language of the human: the
 * catalogue holds the sentence of every code. A failure that carries no code
 * is the output of the program or of the host; it is shown as it is, because
 * it reports what happened rather than what the interface says.
 */
export function errorText(t: Translate, error: unknown): string {
  const coded = readCodedError(error);
  if (!coded) return error instanceof Error ? error.message : String(error);
  const key = ERROR_KEYS[coded.code];
  if (coded.detail === undefined) return t(key);
  return t(key, { values: coded.detail });
}
