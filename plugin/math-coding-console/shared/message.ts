import type { en } from "./locales/en";

/**
 * The keys of the catalogue and the way to name a text without writing it.
 *
 * The type lives in `shared/` because the server builds the same steps of the
 * method as the client draws them, and the server must not carry the catalogue
 * of the interface: it names a key and the client turns the key into a text.
 * The import is a type import, so nothing of the catalogue reaches the server
 * bundle.
 */

/**
 * The values a text may hold in place of its own words.
 *
 * A value may be a descriptor as well: a model is built once and drawn later, so
 * a text inside a text is named by a key and read in the language of the human
 * when the model is drawn.
 */
export type MessageArgs = Record<string, string | number | MessageRef>;

type DotPaths<T> = T extends string
  ? never
  : {
      [K in keyof T & string]: T[K] extends string ? K : `${K}.${DotPaths<T[K]>}`;
    }[keyof T & string];

/**
 * A key with a count is named by its base.
 *
 * The plural forms `one`, `few`, `many` and `other` are chosen by the language,
 * so the caller names the base and passes the number.
 */
type PluralBase<S extends string> = S extends
  `${infer Base}_${"zero" | "one" | "two" | "few" | "many" | "other"}`
  ? Base
  : S;

/** Every key the catalogue holds. */
export type MessageKey = PluralBase<DotPaths<typeof en>>;

/**
 * A text of the interface named by its key.
 *
 * The step of the method is built once and drawn in two places: the interface
 * shows it, the server runs it. A descriptor keeps the two apart: the builder
 * says which key it means, the reader of the interface asks for the language it
 * speaks.
 */
export interface MessageRef {
  key: MessageKey;
  args?: MessageArgs;
}
