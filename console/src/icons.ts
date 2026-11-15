import {
  ArrowLeft,
  Bot,
  Box,
  Boxes,
  Check,
  ChevronDown,
  ChevronsUp,
  CircleDashed,
  CircleHelp,
  CircleOff,
  Clipboard,
  Clock3,
  FileClock,
  FileQuestion,
  FileText,
  FileWarning,
  FilterX,
  FoldVertical,
  Folder,
  FolderTree,
  History,
  Inbox,
  ListTree,
  ListX,
  Map,
  Maximize2,
  Play,
  RefreshCw,
  ScanSearch,
  Search,
  SearchX,
  ShieldAlert,
  ShieldCheck,
  ShieldX,
  UnfoldVertical,
  User,
  UserRoundCheck,
  Workflow,
  X,
  icons as lucideIcons,
  type LucideIcon,
} from "lucide-react";

/**
 * Icon names are passed by the shared interface as strings.
 *
 * The browser host resolves them against the Lucide catalogue. An unknown name
 * never breaks the page: it falls back to a neutral glyph and says so.
 *
 * The names the interface uses are imported one by one, so the page carries
 * only the glyphs it draws. The catalogue behind them answers every other
 * canonical Lucide name.
 */

export const ICON_FALLBACK_NAME = "CircleHelp";

const REGISTERED: Record<string, LucideIcon> = {
  ArrowLeft,
  Bot,
  Box,
  Boxes,
  Check,
  ChevronDown,
  ChevronsUp,
  CircleDashed,
  CircleHelp,
  CircleOff,
  Clipboard,
  Clock3,
  FileClock,
  FileQuestion,
  FileText,
  FileWarning,
  FilterX,
  FoldVertical,
  Folder,
  FolderTree,
  History,
  Inbox,
  ListTree,
  ListX,
  Map,
  Maximize2,
  Play,
  RefreshCw,
  ScanSearch,
  Search,
  SearchX,
  ShieldAlert,
  ShieldCheck,
  ShieldX,
  UnfoldVertical,
  User,
  UserRoundCheck,
  Workflow,
  X,
};

const CATALOGUE = lucideIcons as unknown as Record<string, LucideIcon>;

export interface ResolvedIcon {
  /** The name that was requested. */
  requested: string;
  /** The name that is actually drawn. */
  name: string;
  component: LucideIcon;
  /** True when the requested name is unknown and the fallback is used. */
  fallback: boolean;
}

export function hasIcon(name: string): boolean {
  return Object.prototype.hasOwnProperty.call(REGISTERED, name)
    || Object.prototype.hasOwnProperty.call(CATALOGUE, name);
}

export function resolveIcon(name: string): ResolvedIcon {
  if (Object.prototype.hasOwnProperty.call(REGISTERED, name)) {
    return { requested: name, name, component: REGISTERED[name], fallback: false };
  }
  if (Object.prototype.hasOwnProperty.call(CATALOGUE, name)) {
    return { requested: name, name, component: CATALOGUE[name], fallback: false };
  }
  return {
    requested: name,
    name: ICON_FALLBACK_NAME,
    component: REGISTERED[ICON_FALLBACK_NAME],
    fallback: true,
  };
}
