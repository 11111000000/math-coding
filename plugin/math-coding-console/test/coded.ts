import { CodedError, type ErrorCode } from "../shared/errors";

/**
 * The check of a failure that travels as a code.
 *
 * A failure the human is meant to read reaches the client as a code, and the
 * catalogue turns it into a sentence in the language of the human. The test
 * therefore names the code and never the sentence: the sentence belongs to the
 * catalogue, and the catalogue has a test of its own.
 */
export function coded(code: ErrorCode) {
  return (error: unknown): boolean => error instanceof CodedError && error.code === code;
}
