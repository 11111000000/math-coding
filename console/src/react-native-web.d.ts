/**
 * react-native-web ships no type declarations of its own.
 *
 * The browser host draws with the same primitives as the shared interface, so
 * the declarations of react-native describe them exactly.
 */
declare module "react-native-web" {
  export * from "react-native";
}
