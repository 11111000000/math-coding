import type { MessageKey as MessageKeyOf } from "../../shared/message";

/**
 * The keys of the catalogue.
 *
 * The keys are the paths of the English catalogue. A key with a count is
 * named by its base: the plural forms `one`, `few`, `many` and `other` are
 * chosen by the language, so the caller names the base and the number.
 *
 * The type itself lives in `shared/`, because the server names the same keys
 * when it builds a step of the method.
 */
export type MessageKey = MessageKeyOf;
