/**
 * The rules of the file preview.
 *
 * The panel decides whether the preview is open: it hands the preview a path
 * or it hands it nothing. The preview never decides that on its own and never
 * keeps a path from the moment it was mounted, so a path that arrives later
 * opens the preview like a path that was there from the start.
 *
 * Navigation inside the preview is the only local state: the human walks into
 * a directory and comes back up, while the path of the panel stays the path
 * that was asked for.
 */

/** The path the preview shows: the requested path, or the one it walked to. */
export function previewTarget(path: string | null, navigated: string | null): string | null {
  return navigated ?? path;
}

/** The preview is open while the panel asks for a path. */
export function previewIsOpen(path: string | null): boolean {
  return path !== null;
}

/** The directory that contains the shown path, or null at the root. */
export function previewParent(path: string | null): string | null {
  if (!path || !path.includes("/")) return null;
  return path.slice(0, path.lastIndexOf("/"));
}

/** The path of an entry of the shown directory. */
export function previewChild(path: string | null, name: string): string {
  return path ? `${path}/${name}` : name;
}
